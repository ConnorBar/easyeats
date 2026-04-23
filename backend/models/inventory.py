from pydantic import BaseModel
from typing import Optional, List


class PriceEntry(BaseModel):
    store: str
    price: float
    date: str


class Batch(BaseModel):
    quantity: float
    expireDate: Optional[str] = None


class InventoryItemCreate(BaseModel):
    name: str
    quantity: float
    unit: str
    expireDate: Optional[str] = None
    priceHistory: List[PriceEntry] = []


class InventoryItemUpdate(BaseModel):
    name: Optional[str] = None
    unit: Optional[str] = None
    batches: Optional[List[Batch]] = None
    priceHistory: Optional[List[PriceEntry]] = None


class InventoryItemResponse(BaseModel):
    id: str
    name: str
    quantity: float
    unit: str
    expireDate: Optional[str] = None
    batches: List[Batch] = []
    priceHistory: List[PriceEntry] = []
