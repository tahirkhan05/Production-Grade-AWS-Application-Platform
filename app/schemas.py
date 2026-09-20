from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

# Item Schemas
class ItemBase(BaseModel):
    name: str = Field(..., example="Wireless Ergonomic Mouse")
    description: Optional[str] = Field(None, example="2.4GHz wireless mouse with silent clicks")
    price: float = Field(..., gt=0, example=29.99)
    stock_quantity: int = Field(..., ge=0, example=150)

class ItemCreate(ItemBase):
    pass

class ItemResponse(ItemBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True

# Order Item Schemas
class OrderItemCreate(BaseModel):
    item_id: int
    quantity: int = Field(..., gt=0, example=2)

class OrderItemResponse(BaseModel):
    item_id: int
    quantity: int
    unit_price: float

    class Config:
        from_attributes = True

# Order Schemas
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
