# --- Base image ---
FROM python:3.11-slim

# --- Install system dependencies ---
RUN apt-get update && apt-get install -y \
    gcc g++ unixodbc-dev build-essential \
    libpoppler-cpp-dev pkg-config python3-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Environment ---
ENV PYTHONUNBUFFERED=1

# --- Set working directory ---
WORKDIR /app

# --- Copy requirements first ---
COPY requirements.txt .

# --- Install Python dependencies ---
RUN pip install --no-cache-dir -r requirements.txt

# --- Copy app code ---
COPY . .

# --- Expose port (Azure will set PORT env variable) ---
EXPOSE 8080

# --- Run Flask app using gunicorn ---
# Azure App Service sets the PORT env variable automatically
CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT:-8080} --workers=2 --threads=4 --timeout=300 app:app"]
