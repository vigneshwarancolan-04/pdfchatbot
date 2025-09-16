# ----------------------------
# Dockerfile for PDF Chatbot with working ODBC
# ----------------------------

FROM python:3.11-slim

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /app

# ----------------------------
# Install system dependencies
# ----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    unixodbc-dev \
    gcc \
    g++ \
    curl \
    gnupg \
    apt-transport-https \
    lsb-release \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Install Microsoft ODBC Driver 17 for SQL Server (repository method)
# ----------------------------
RUN curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.gpg \
    && curl https://packages.microsoft.com/config/debian/12/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y msodbcsql17 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Copy requirements and install Python packages
# ----------------------------
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# ----------------------------
# Download NLTK stopwords
# ----------------------------
RUN python -m nltk.downloader stopwords

# ----------------------------
# Copy app source
# ----------------------------
COPY . /app/

# ----------------------------
# Expose Azure port
# ----------------------------
EXPOSE 8080

# ----------------------------
# Start Gunicorn
# ----------------------------
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
