# Base image
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ unixodbc-dev build-essential \
    libpoppler-cpp-dev pkg-config python3-dev curl git \
    && rm -rf /var/lib/apt/lists/*

# Set workdir
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Upgrade pip + wheel + setuptools
RUN pip install --upgrade pip setuptools wheel

# Install PyTorch first (CPU-only, faster & avoids compilation)
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Then install rest of the requirements
RUN pip install --no-cache-dir -r requirements.txt

# Copy app code
COPY . .

# Expose port
EXPOSE 8080

# Run app with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers=2", "--threads=4", "--timeout=300", "app:app"]
