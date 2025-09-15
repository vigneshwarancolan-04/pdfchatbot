import os
import uuid
import datetime
import fitz
import nltk
import pyodbc   
from flask import Flask, render_template, request, redirect, url_for, flash
from sentence_transformers import SentenceTransformer, util
from openai import OpenAI, OpenAIError
import chromadb
from nltk.corpus import stopwords
from dotenv import load_dotenv

# --- Setup ---
nltk.download("stopwords", quiet=True)
stop_words = set(stopwords.words("english"))
load_dotenv(".env")  

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "supersecretkey")
app.config['UPLOAD_FOLDER'] = 'pdfs'
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs('chroma_store', exist_ok=True)

# --- Environment Variables ---
SQL_SERVER = os.getenv("SQL_SERVER")       
SQL_DB = os.getenv("SQL_DB")               
SQL_USER = os.getenv("SQL_USER")           
SQL_PASSWORD = os.getenv("SQL_PASSWORD")   
VECTORSTORE_PATH = os.getenv("VECTORSTORE_PATH", "chroma_store")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
MODEL_NAME = os.getenv("MODEL_NAME")

# --- Check API Key ---
if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY environment variable missing")

# --- Embeddings & Chroma ---
embedder = SentenceTransformer("all-MiniLM-L6-v2")
chroma_client = chromadb.PersistentClient(path=VECTORSTORE_PATH)
collection = chroma_client.get_or_create_collection("rag_docs")

# --- Groq Client ---
try:
    client = OpenAI(api_key=GROQ_API_KEY, base_url="https://api.groq.com/openai/v1")
except OpenAIError as e:
    print("[ERROR] Failed to initialize Groq client:", e)
    raise

# --- Database (Azure SQL) ---
def get_db():
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_SERVER};"
        f"DATABASE={SQL_DB};"
        f"UID={SQL_USER};"
        f"PWD={SQL_PASSWORD}"
    )
    return pyodbc.connect(conn_str)

# --- Utilities ---
def clean_session_name(text):
    words = text.split()
    filtered = [w for w in words if w.lower() not in stop_words]
    return " ".join(filtered[:6]).title() or "New Chat"

def load_sessions():
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("SELECT id, title, created_at FROM sessions ORDER BY created_at DESC")
        result = cursor.fetchall()
        db.close()
        return [{"id": sid, "title": title} for sid, title, _ in result]
    except Exception as e:
        print("DB Error load_sessions:", e)
        return []

def load_history(session_id):
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("SELECT question, answer FROM chat_history WHERE session_id = ? ORDER BY timestamp", (session_id,))
        rows = cursor.fetchall()
        db.close()
        return [{"question": q, "answer": a} for q, a in rows]
    except Exception as e:
        print("DB Error load_history:", e)
        return []

def save_chat(session_id, question, answer):
    try:
        db = get_db()
        cursor = db.cursor()
        cursor.execute("SELECT COUNT(*) FROM chat_history WHERE session_id = ?", (session_id,))
        count = cursor.fetchone()[0]

        if count == 0:
            title = clean_session_name(question)
            cursor.execute("INSERT INTO sessions (id, title, created_at) VALUES (?, ?, ?)",
                           (session_id, title, datetime.datetime.now()))

        cursor.execute("INSERT INTO chat_history (session_id, question, answer, timestamp) VALUES (?, ?, ?, ?)",
                       (session_id, question, answer, datetime.datetime.now()))
        db.commit()
        db.close()
    except Exception as e:
        print("DB Error save_chat:", e)

# --- RAG helpers ---
def semantic_chunk_text(text, max_tokens=500, similarity_threshold=0.7):
    sentences = text.split(". ")
    chunks, current_chunk = [], ""
    current_embedding = None

    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue
        temp_chunk = f"{current_chunk} {sentence}".strip()
        temp_embedding = embedder.encode(temp_chunk, convert_to_tensor=True)
        similarity = 1.0 if current_embedding is None else util.pytorch_cos_sim(current_embedding, temp_embedding).item()

        if len(temp_chunk) > max_tokens or similarity < similarity_threshold:
            if current_chunk:
                chunks.append(current_chunk.strip())
            current_chunk = sentence
            current_embedding = embedder.encode(current_chunk, convert_to_tensor=True)
        else:
            current_chunk = temp_chunk
            current_embedding = temp_embedding

    if current_chunk:
        chunks.append(current_chunk.strip())
    return chunks

def process_pdf(pdf_path, filename):
    doc = fitz.open(pdf_path)
    for page_num, page in enumerate(doc):
        chunks = semantic_chunk_text(page.get_text())
        for i, chunk in enumerate(chunks):
            collection.add(
                documents=[chunk],
                metadatas=[{"source": filename, "page": page_num}],
                ids=[f"{filename}_p{page_num}_c{i}"]
            )

def search_chunks(query, k=3):
    results = collection.query(query_texts=[query], n_results=k)
    return list(zip(results["documents"][0], results["metadatas"][0], results["distances"][0]))

def build_prompt(question, chunks):
    context = "\n\n".join([doc for doc, _, _ in chunks])
    return f"""You are a helpful assistant. Use ONLY the context below to answer the question.

Context:
{context}

Question: {question}
Answer:"""

# --- Routes ---
@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        pdf = request.files.get("pdf")
        if pdf and pdf.filename.lower().endswith(".pdf"):
            filename = pdf.filename
            save_path = os.path.join(app.config["UPLOAD_FOLDER"], filename)
            pdf.save(save_path)
            process_pdf(save_path, filename)
            session_id = str(uuid.uuid4())
            return redirect(url_for("chat", session_id=session_id))

    sessions = load_sessions()
    return render_template("index.html", sessions=sessions)

@app.route("/chat/<session_id>", methods=["GET", "POST"])
def chat(session_id):
    sessions = load_sessions()
    history = load_history(session_id)

    if request.method == "POST" and 'question' in request.form:
        question = request.form.get("question", "").strip()
        if question:
            chunks = search_chunks(question)
            prompt = build_prompt(question, chunks)
            try:
                response = client.chat.completions.create(
                    model=MODEL_NAME,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.7,
                    max_tokens=300
                )
                answer = response.choices[0].message.content.strip()
            except OpenAIError as e:
                print("Groq API Error:", e)
                answer = "Error: Could not fetch response from Groq API."

            save_chat(session_id, question, answer)
            history.append({"question": question, "answer": answer})

        return render_template("chat.html", session_id=session_id, sessions=sessions, history=history)

    return render_template("chat.html", session_id=session_id, sessions=sessions, history=history)

# --- Main ---
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8181))
    app.run(host="0.0.0.0", port=port, debug=True)
