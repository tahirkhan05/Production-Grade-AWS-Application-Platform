import os
import time
from typing import List
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

import models
import schemas
from database import engine, get_db, check_db_health, Base

try:
    Base.metadata.create_all(bind=engine)
except Exception as e:
    print(f"Database table initialization notice: {e}")

app = FastAPI(
    title="Enterprise Cloud Inventory API",
    description="Production-Grade AWS Application Platform Microservice",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

START_TIME = time.time()

@app.get("/", tags=["General"])
def root():
    return {
        "service": "Production-Grade AWS Application Platform",
        "environment": os.getenv("APP_ENV", "production"),
        "version": "1.0.0",
        "status": "healthy",
        "docs": "/docs"
    }

@app.get("/health", tags=["Observability"])
def liveness_probe():
    """Liveness probe for AWS Application Load Balancer."""
    return {"status": "UP", "timestamp": time.time()}

@app.get("/ready", tags=["Observability"])
def readiness_probe():
    """Readiness probe checking database connectivity."""
    db_healthy, message = check_db_health()
    if not db_healthy:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "DOWN", "database": message}
        )
    return {
        "status": "READY",
        "database": "connected",
        "uptime_seconds": round(time.time() - START_TIME, 2)
    }

# ----------------- Inventory Endpoints ----------------- #

@app.post("/items", response_model=schemas.ItemResponse, status_code=status.HTTP_201_CREATED, tags=["Inventory"])
def create_item(item: schemas.ItemCreate, db: Session = Depends(get_db)):
    db_item = models.Item(
        name=item.name,
        description=item.description,
        price=item.price,
        stock_quantity=item.stock_quantity
    )
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

@app.get("/items", response_model=List[schemas.ItemResponse], tags=["Inventory"])
def list_items(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.Item).offset(skip).limit(limit).all()

@app.get("/items/{item_id}", response_model=schemas.ItemResponse, tags=["Inventory"])
def get_item(item_id: int, db: Session = Depends(get_db)):
    item = db.query(models.Item).filter(models.Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item

# ----------------- Orders Endpoints ----------------- #

@app.post("/orders", response_model=schemas.OrderResponse, status_code=status.HTTP_201_CREATED, tags=["Orders"])
def create_order(order: schemas.OrderCreate, db: Session = Depends(get_db)):
    total_amount = 0.0
    order_items_to_create = []

    for item_req in order.items:
        db_item = db.query(models.Item).filter(models.Item.id == item_req.item_id).first()
        if not db_item:
            raise HTTPException(status_code=404, detail=f"Item with ID {item_req.item_id} not found")
        if db_item.stock_quantity < item_req.quantity:
            raise HTTPException(status_code=400, detail=f"Insufficient stock for '{db_item.name}'. Available: {db_item.stock_quantity}")

        db_item.stock_quantity -= item_req.quantity
        line_price = db_item.price * item_req.quantity
        total_amount += line_price

        order_items_to_create.append({
            "item_id": db_item.id,
            "quantity": item_req.quantity,
            "unit_price": db_item.price
        })

    db_order = models.Order(
        customer_name=order.customer_name,
        total_amount=round(total_amount, 2),
        status="CONFIRMED"
    )
    db.add(db_order)
    db.flush()

    for item_data in order_items_to_create:
        db_order_item = models.OrderItem(
            order_id=db_order.id,
            item_id=item_data["item_id"],
            quantity=item_data["quantity"],
            unit_price=item_data["unit_price"]
        )
        db.add(db_order_item)

    db.commit()
    db.refresh(db_order)
    return db_order

@app.get("/orders", response_model=List[schemas.OrderResponse], tags=["Orders"])
def list_orders(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return db.query(models.Order).offset(skip).limit(limit).all()
