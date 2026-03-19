FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir confluent-kafka==2.5.3
COPY simulator.py /app/simulator.py
CMD ["python", "-u", "simulator.py"]
