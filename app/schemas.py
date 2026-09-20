from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

# ==============================================================================
# PYDANTIC SCHEMAS (DATA VALIDATION & SERIALIZATION)
# ==============================================================================
# Why do we need Schemas separate from Models?
# - Models (models.py) define how data is stored inside PostgreSQL.
# - Schemas (schemas.py) define what JSON data users are allowed to SEND into our API,
#   and what JSON structure our API will RETURN to users.
#
# Pydantic automatically validates types (e.g. ensuring price is a positive number).
# If a client sends invalid data, FastAPI returns a clear 422 Unprocessable Entity error.
# ==============================================================================

# --- ITEM SCHEMAS ---

class ItemBase(BaseModel):
    name: str = Field(..., example="Wireless Ergonomic Mouse")
    description: Optional[str] = Field(None, example="2.4GHz wireless mouse with silent clicks")
    price: float = Field(..., gt=0, example=29.99) # gt=0 means price MUST be greater than 0
    stock_quantity: int = Field(..., ge=0, example=150) # ge=0 means quantity cannot be negative

class ItemCreate(ItemBase):
    """Schema used when receiving a POST /items request (client doesn't provide id or created_at)."""
    pass

class ItemResponse(ItemBase):
    """Schema used when returning item data to the client (includes generated database ID & timestamp)."""
    id: int
    created_at: datetime

    class Config:
        from_attributes = True # Allows Pydantic to read SQLAlchemy ORM objects directly


# --- ORDER ITEM SCHEMAS ---

class OrderItemCreate(BaseModel):
    item_id: int
    quantity: int = Field(..., gt=0, example=2)

class OrderItemResponse(BaseModel):
    item_id: int
    quantity: int
    unit_price: float

    class Config:
        from_attributes = True


# --- ORDER SCHEMAS ---

class OrderCreate(BaseModel):
    customer_name: str = Field(..., example="Sarah Connor")
    items: List[OrderItemCreate]

class OrderResponse(BaseModel):
    id: int
    customer_name: str
    total_amount: float
    status: str
    created_at: datetime
    items: List[OrderItemResponse]

    class Config:
        from_attributes = True
