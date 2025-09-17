# --- Base image ---
FROM python:3.11-slim

# --- System deps ---
RUN apt-get update && apt-get install -y \
    gcc g++ curl gnupg2 apt-transport-https unixodbc-dev \
    build-essential libpoppler-cpp-dev pkg-config python3-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Install Microsoft ODBC Driver 17 for SQL Server ---
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/12/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql17 && \
    rm -rf /var/lib/apt/lists/*

# --- Set work directory ---
WORKDIR /app

# --- Copy requirements first (better caching) ---
COPY requirements.txt .

# --- Install Python deps ---
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# --- Copy app code ---
COPY . .

# --- Expose port ---
EXPOSE 8080

# --- Start with Gunicorn ---
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers=2", "--threads=4", "--timeout=300", "app:app"]
