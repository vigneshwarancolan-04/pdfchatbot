FROM python:3.11-slim

# Prevent Python from writing pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    unixodbc-dev \
    gcc \
    g++ \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN pip install --upgrade pip

# Copy requirements and install Python deps
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Download NLTK stopwords
RUN python -m nltk.downloader stopwords

# Copy application code
COPY . /app/

# Expose default port for local runs
EXPOSE 8080

# Use $PORT if provided by Azure, otherwise fallback to 8080
CMD gunicorn --bind 0.0.0.0:${PORT:-8080} --workers=2 --threads=4 --timeout=300 app:app
