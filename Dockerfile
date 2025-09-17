# --- Base image ---
FROM python:3.11-slim

# --- Set environment variables ---
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

# --- Install system dependencies ---
RUN apt-get update && apt-get install -y \
    gcc g++ unixodbc-dev build-essential \
    libpoppler-cpp-dev pkg-config python3-dev curl git \
    && rm -rf /var/lib/apt/lists/*

# --- Set working directory ---
WORKDIR /app

# --- Copy requirements and install ---
COPY requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# --- Copy app source code ---
COPY . .

# --- Expose port ---
EXPOSE 8080

# --- Start Gunicorn ---
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers=1", "--threads=2", "--timeout=300", "app:app"]
