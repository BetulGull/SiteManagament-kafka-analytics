FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir confluent-kafka==2.5.3
COPY analytics.py /app/analytics.py
CMD ["python", "-u", "analytics.py"]
