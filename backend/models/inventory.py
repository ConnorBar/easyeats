from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
import re

"""
Pydantic enforces type safety - this prevents users from being able to sneak in different data
types to cause damage to the database. Field constraints add length limits and value bounds
to prevent oversized payloads and negative quantities. field_validators sanitize strings
(strip whitespace, reject blank-after-strip) and validate date format.
"""

class PriceEntry(BaseModel):
    store: str = Field(min_length=1, max_length=100)
    price: float = Field(gt=0)
    date: str = Field(min_length=1, max_length=10)

    @field_validator("store")
    @classmethod
    def strip_store(cls, v: str) -> str:
        return v.strip()

    @field_validator("date")
    @classmethod
    def validate_date_format(cls, v: str) -> str:
        if not re.match(r"^\d{4}-\d{2}-\d{2}$", v):
            raise ValueError("date must be YYYY-MM-DD")
        return v


class Batch(BaseModel):
    quantity: float = Field(gt=0)
    expireDate: Optional[str] = None

    @field_validator("expireDate")
    @classmethod
    def validate_expire_date(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and not re.match(r"^\d{4}-\d{2}-\d{2}$", v):
            raise ValueError("expireDate must be YYYY-MM-DD")
        return v


class InventoryItemCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    quantity: float = Field(ge=0)  # 0 allowed: recipe sheet creates placeholder ingredients with qty=0
    unit: str = Field(min_length=1, max_length=20)
    expireDate: Optional[str] = None
    priceHistory: List[PriceEntry] = Field(default=[], max_length=500)

    @field_validator("name", "unit")
    @classmethod
    def strip_strings(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("field cannot be blank")
        return stripped

    @field_validator("expireDate")
    @classmethod
    def validate_expire_date(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and not re.match(r"^\d{4}-\d{2}-\d{2}$", v):
            raise ValueError("expireDate must be YYYY-MM-DD")
        return v


class InventoryItemUpdate(BaseModel):
    name: Optional[str] = Field(default=None, max_length=100)
    unit: Optional[str] = Field(default=None, max_length=20)
    batches: Optional[List[Batch]] = Field(default=None, max_length=1000)
    priceHistory: Optional[List[PriceEntry]] = Field(default=None, max_length=500)

    @field_validator("name", "unit")
    @classmethod
    def strip_strings(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            stripped = v.strip()
            if not stripped:
                raise ValueError("field cannot be blank")
            return stripped
        return v


class InventoryItemResponse(BaseModel):
    id: str
    name: str
    quantity: float
    unit: str
    expireDate: Optional[str] = None
    batches: List[Batch] = []
    priceHistory: List[PriceEntry] = []
