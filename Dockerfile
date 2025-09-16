
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
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*


RUN pip install --upgrade pip


COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt


RUN python -m nltk.downloader stopwords


COPY . /app/


EXPOSE 8080


CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
