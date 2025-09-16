FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    unixodbc-dev \
    gcc \
    g++ \
    curl \
    apt-transport-https \
    lsb-release \
    libgl1 \
    libglib2.0-0 \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://packages.microsoft.com/debian/12/prod/pool/main/m/msodbcsql17/msodbcsql17_18.2.1.1-1_amd64.deb -o /tmp/msodbcsql17.deb \
    && dpkg -i /tmp/msodbcsql17.deb || apt-get install -f -y \
    && rm /tmp/msodbcsql17.deb

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

RUN python -m nltk.downloader stopwords

COPY . /app/

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
