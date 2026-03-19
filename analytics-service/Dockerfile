FROM python:3.11-slim
WORKDIR /app

RUN pip install --no-cache-dir confluent-kafka==2.5.3 firebase-admin

COPY analytics-service/app.py /app/app.py
COPY analytics-service/serviceAccountKey.json /app/serviceAccountKey.json
COPY shared /app/shared

ENV FIREBASE_KEY_PATH=/app/serviceAccountKey.json
ENV KAFKA_SSL_CA_LOCATION=/app/shared/ca.pem

CMD ["python", "-u", "/app/app.py"]
