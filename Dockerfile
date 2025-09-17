# Base image
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ unixodbc-dev build-essential \
    libpoppler-cpp-dev pkg-config python3-dev curl git ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Upgrade pip, wheel, setuptools
RUN pip install --upgrade pip setuptools wheel

# Install PyTorch CPU first (avoids heavy compilation)
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install other Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy app source code
COPY . .

# Expose port
EXPOSE 8080

# Run app with Gunicorn
CMD ["python", "app.py"]
