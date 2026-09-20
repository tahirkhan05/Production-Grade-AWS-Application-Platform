import os
import time
from typing import List
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

import models
import schemas
from database import engine, get_db, check_db_health, Base

# ==============================================================================
# APPLICATION BOOTSTRAP & SCHEMA INITIALIZATION
# ==============================================================================
# When the container starts, this command automatically creates the 'items',
# 'orders', and 'order_items' tables in PostgreSQL if they do not exist yet.
# ==============================================================================
try:
    Base.metadata.create_all(bind=engine)
except Exception as e:
    print(f"[BOOTSTRAP] Database tables initialization notice: {e}")

# Create the FastAPI instance with interactive documentation metadata
app = FastAPI(
    title="Enterprise Cloud Inventory API",
    description="Production-Grade AWS Application Platform - Enterprise REST API",
    version="1.0.0",
    docs_url="/docs",      # Swagger UI endpoint
    redoc_url="/redoc"     # ReDoc UI endpoint
)

START_TIME = time.time()


# ==============================================================================
# GENERAL & OBSERVABILITY (HEALTH CHECK) ENDPOINTS
# ==============================================================================

@app.get("/", tags=["General"])
def root():
    """
    Root endpoint returning service identity, environment, and documentation links.
    """
    return {
        "service": "Production-Grade AWS Application Platform",
        "environment": os.getenv("APP_ENV", "production"),
        "version": "1.0.0",
        "status": "healthy",
        "docs": "/docs"
    }


@app.get("/health", tags=["Observability"])
def liveness_probe():
    """
    LIVENESS PROBE (Used by AWS Application Load Balancer):
    - The ALB sends an HTTP GET request to '/health' every 15 seconds.
    - If the container responds with HTTP 200, the ALB knows the container process is alive.
    - If a container crashes or freezes, ALB marks it 'unhealthy' and redirects traffic
      to the other healthy container in the alternate Availability Zone.
    """
    return {"status": "UP", "timestamp": time.time()}


@app.get("/ready", tags=["Observability"])
def readiness_probe():
    """
    READINESS PROBE (Verifies dependency health):
    - Verifies that the container can successfully reach and query the PostgreSQL database.
    - Returns HTTP 200 if connected, or HTTP 503 if database connection is down.
    """
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


# ==============================================================================
# INVENTORY MANAGEMENT ENDPOINTS
# ==============================================================================

@app.post("/items", response_model=schemas.ItemResponse, status_code=status.HTTP_201_CREATED, tags=["Inventory"])
def create_item(item: schemas.ItemCreate, db: Session = Depends(get_db)):
    """
    Create a new inventory item in PostgreSQL.
    """
    db_item = models.Item(
        name=item.name,
        description=item.description,
        price=item.price,
        stock_quantity=item.stock_quantity
    )
    db.add(db_item)
    db.commit()          # Commit transaction to persist record
    db.refresh(db_item)  # Refresh object to populate generated primary key 'id'
    return db_item


@app.get("/items", response_model=List[schemas.ItemResponse], tags=["Inventory"])
def list_items(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """
    Retrieve a paginated list of inventory items.
    """
    return db.query(models.Item).offset(skip).limit(limit).all()


@app.get("/items/{item_id}", response_model=schemas.ItemResponse, tags=["Inventory"])
def get_item(item_id: int, db: Session = Depends(get_db)):
    """
    Fetch a single item by its ID. Returns HTTP 404 if item does not exist.
    """
    item = db.query(models.Item).filter(models.Item.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


# ==============================================================================
# ORDER PROCESSING ENDPOINTS
# ==============================================================================

@app.post("/orders", response_model=schemas.OrderResponse, status_code=status.HTTP_201_CREATED, tags=["Orders"])
def create_order(order: schemas.OrderCreate, db: Session = Depends(get_db)):
    """
    Process a new customer order:
    1. Validates that requested items exist and warehouse has sufficient stock.
    2. Atomically decrements the stock quantity for each item.
    3. Calculates total amount and records the order with items in PostgreSQL.
    """
    total_amount = 0.0
    order_items_to_create = []

    # Validate all items and reserve stock
    for item_req in order.items:
        db_item = db.query(models.Item).filter(models.Item.id == item_req.item_id).first()
        if not db_item:
            raise HTTPException(
                status_code=404,
                detail=f"Item with ID {item_req.item_id} not found"
            )
        if db_item.stock_quantity < item_req.quantity:
            raise HTTPException(
                status_code=400,
                detail=f"Insufficient stock for '{db_item.name}'. Available: {db_item.stock_quantity}, Requested: {item_req.quantity}"
            )

        # Deduct inventory count
        db_item.stock_quantity -= item_req.quantity
        line_price = db_item.price * item_req.quantity
        total_amount += line_price

        order_items_to_create.append({
            "item_id": db_item.id,
            "quantity": item_req.quantity,
            "unit_price": db_item.price
        })

    # Create Order parent record
    db_order = models.Order(
        customer_name=order.customer_name,
        total_amount=round(total_amount, 2),
        status="CONFIRMED"
    )
    db.add(db_order)
    db.flush() # Flushes SQL so db_order.id is generated for children items

    # Create OrderItem child records
    for item_data in order_items_to_create:
        db_order_item = models.OrderItem(
            order_id=db_order.id,
            item_id=item_data["item_id"],
            quantity=item_data["quantity"],
            unit_price=item_data["unit_price"]
        )
        db.add(db_order_item)

    # Commit the entire atomic transaction
    db.commit()
    db.refresh(db_order)
    return db_order


@app.get("/orders", response_model=List[schemas.OrderResponse], tags=["Orders"])
def list_orders(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """
    Retrieve a list of customer orders with their purchased items.
    """
    return db.query(models.Order).offset(skip).limit(limit).all()
