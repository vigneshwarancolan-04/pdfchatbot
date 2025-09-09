# Use slim Python 3.11 image
FROM python:3.11-slim

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    VECTORSTORE_PATH=/app/chroma_store \
    UPLOAD_FOLDER=/app/pdfs \
    PORT=80

# Install system dependencies (incl. ODBC for Azure SQL)
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

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install pyodbc  

# Copy app code
COPY . .

# Download NLTK data (stopwords)
RUN python -m nltk.downloader stopwords

# Create folders for uploads and vector store
RUN mkdir -p ${UPLOAD_FOLDER} ${VECTORSTORE_PATH}

# Expose port
EXPOSE 80

# Start Flask app
CMD ["python", "app.py"]
