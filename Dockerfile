# ===== STAGE 1: Build stage =====
FROM python:3.11-slim AS builder

# Environment variables
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
    apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql17 unixodbc-dev

# Set working directory
WORKDIR /app

# Copy requirements and install Python packages
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install pyodbc gunicorn nltk

# Download NLTK stopwords
RUN python -m nltk.downloader stopwords

# Copy application code
COPY . .

# ===== STAGE 2: Runtime stage =====
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VECTORSTORE_PATH=/app/chroma_store \
    UPLOAD_FOLDER=/app/pdfs \
    PORT=80

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    poppler-utils \
    libgl1 \
    unixodbc \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy app code and NLTK data
COPY --from=builder /app /app
ENV NLTK_DATA=/usr/local/share/nltk_data

# Create folders for uploads and vector store
RUN mkdir -p ${UPLOAD_FOLDER} ${VECTORSTORE_PATH}

# Expose port
EXPOSE 80

# Start app with Gunicorn (increase timeout)
CMD ["gunicorn", "--bind", "0.0.0.0:80", "--timeout", "300", "app:app"]
