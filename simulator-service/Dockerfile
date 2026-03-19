FROM python:3.11-slim
WORKDIR /app

RUN pip install --no-cache-dir confluent-kafka==2.5.3

COPY simulator-service/app.py /app/app.py
COPY shared /app/shared

ENV KAFKA_SSL_CA_LOCATION=/app/shared/ca.pem

CMD ["python", "-u", "/app/app.py"]
