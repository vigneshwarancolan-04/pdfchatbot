# ===== STAGE 1: Build stage =====
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    pkg-config \
    poppler-utils \
    libpoppler-cpp-dev \
    libgl1 \
    git \
    curl \
    gnupg \
    unixodbc \
    unixodbc-dev \
    freetds-dev \
    freetds-bin \
    tdsodbc \
    && rm -rf /var/lib/apt/lists/*

# Install Microsoft ODBC Driver 17 for SQL Server
RUN curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/11/prod bullseye main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql17

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install pyodbc gunicorn nltk chromadb sentence-transformers openai fitz

# Download NLTK stopwords
RUN python -m nltk.downloader -d /usr/local/share/nltk_data stopwords

# Copy the app source code
COPY . .

# ===== STAGE 2: Runtime stage =====
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VECTORSTORE_PATH=/app/chroma_store \
    UPLOAD_FOLDER=/app/pdfs \
    PORT=8080 \
    NLTK_DATA=/usr/local/share/nltk_data

# Install runtime dependencies + ODBC driver
RUN apt-get update && apt-get install -y \
    poppler-utils \
    libgl1 \
    unixodbc \
    msodbcsql17 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/share/nltk_data /usr/local/share/nltk_data

# Copy app code
COPY --from=builder /app /app

# Create required folders
RUN mkdir -p ${UPLOAD_FOLDER} ${VECTORSTORE_PATH}

EXPOSE 8080

# Start the app with Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--timeout", "300", "app:app"]
