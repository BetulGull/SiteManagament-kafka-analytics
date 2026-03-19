import json
import os

import psycopg2
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "ordersdb")
DB_USER = os.getenv("DB_USER", "ordersuser")
DB_PASSWORD = os.getenv("DB_PASSWORD", "orderspass")

app = FastAPI(title="order-service")

class CreateOrder(BaseModel):
    customer: str = Field(min_length=1)
    amount: float = Field(gt=0)

def get_conn():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
    )

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/orders", status_code=201)
def create_order(req: CreateOrder):
    """
    Outbox pattern (temel):
    - orders tablosuna yaz
    - outbox tablosuna event yaz (published_at NULL)
    İkisi aynı transaction içinde: ya ikisi olur ya hiçbiri.
    """
    conn = None
    try:
        conn = get_conn()
        conn.autocommit = False
        cur = conn.cursor()

        cur.execute(
            "INSERT INTO orders (customer, amount) VALUES (%s, %s) RETURNING id;",
            (req.customer, req.amount),
        )
        order_id = cur.fetchone()[0]

        payload = {"order_id": order_id, "customer": req.customer, "amount": req.amount}
        cur.execute(
            "INSERT INTO outbox (event_type, payload) VALUES (%s, %s);",
            ("OrderCreated", json.dumps(payload)),
        )

        conn.commit()
        cur.close()
        return {"order_id": order_id, "status": "CREATED"}

    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))

    finally:
        if conn:
            conn.close()
