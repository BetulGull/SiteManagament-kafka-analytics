FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .

# Network slow/timeout fix: increase timeout + retries
RUN pip install --no-cache-dir --default-timeout=120 --retries=10 -r requirements.txt

COPY app.py .
COPY outbox_worker.py .

EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
