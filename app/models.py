from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from database import Base

# ==============================================================================
# ORM (OBJECT-RELATIONAL MAPPING) MODELS
# ==============================================================================
# In Python, an ORM allows us to write standard Python classes that automatically
# map to SQL tables inside PostgreSQL. SQLAlchemy translates our Python code into
# real SQL queries (e.g. SELECT, INSERT, UPDATE, DELETE).
# ==============================================================================

class Item(Base):
    """
    Represents an inventory item stored in the 'items' table.
    """
    __tablename__ = "items"

    # Primary Key: unique auto-incrementing integer identifier for each item
    id = Column(Integer, primary_key=True, index=True)
    
    # Item name (e.g., 'Ergonomic Keyboard')
    name = Column(String(100), nullable=False, index=True)
    
    # Optional description of the item
    description = Column(String(255), nullable=True)
    
    # Unit price (e.g., 49.99)
    price = Column(Float, nullable=False)
    
    # Available stock count in warehouse
    stock_quantity = Column(Integer, default=0)
    
    # UTC timestamp when the record was created
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationship: One Item can appear in many OrderItems
    orders = relationship("OrderItem", back_populates="item")


class Order(Base):
    """
    Represents a customer order stored in the 'orders' table.
    """
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    customer_name = Column(String(100), nullable=False)
    total_amount = Column(Float, default=0.0)
    status = Column(String(50), default="CONFIRMED") # e.g., PENDING, CONFIRMED, CANCELLED
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationship: One Order has many OrderItems.
    # cascade="all, delete-orphan" means if an Order is deleted, its items are deleted too.
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")


class OrderItem(Base):
    """
    Join table linking an Order with specific Items, quantities, and historical purchase prices.
    """
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    
    # Foreign Key pointing to the orders table (orders.id)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    
    # Foreign Key pointing to the items table (items.id)
    item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    
    quantity = Column(Integer, default=1)
    unit_price = Column(Float, nullable=False)

    # Navigation properties linking back to the parent Order and Item objects
    order = relationship("Order", back_populates="items")
    item = relationship("Item", back_populates="orders")
