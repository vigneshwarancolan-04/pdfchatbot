# Use slim Python base image
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set work directory
WORKDIR /app

# Install system dependencies (needed for pyodbc, fitz, sentence-transformers)
RUN apt-get update && apt-get install -y \
    build-essential \
    unixodbc-dev \
    gcc \
    g++ \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for caching)
COPY requirements.txt /app/

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Download NLTK stopwords inside container
RUN python -m nltk.downloader stopwords

# Copy project files
COPY . /app/

# Expose port (Azure injects WEBSITES_PORT=8080)
EXPOSE 8080

# Start Gunicorn with dynamic port (Azure expects this)
CMD ["gunicorn", "--bind", "0.0.0.0:${PORT:-8080}", "app:app"]
