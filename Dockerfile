FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

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

# Install Python dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Download NLTK stopwords
RUN python -m nltk.downloader stopwords

# Copy app source
COPY . /app/

# Expose port 8080
EXPOSE 8080

# Gunicorn command (works with Azure)
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
