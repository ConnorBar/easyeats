from pydantic import BaseModel, Field, field_validator
from typing import Optional, List

"""
Pydantic enforces type safety - this prevents users from being able to sneak in different data
types to cause damage to the database. Field constraints add length limits and value bounds
to prevent oversized payloads and negative quantities. field_validators strip and validate strings.
"""

class RecipeIngredient(BaseModel):
    ingredientId: str = Field(min_length=1, max_length=100)
    name: str = Field(min_length=1, max_length=100)
    quantity: float = Field(gt=0)
    unit: str = Field(min_length=1, max_length=20)

    @field_validator("name", "unit")
    @classmethod
    def strip_strings(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("field cannot be blank")
        return stripped


class RecipeCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str = Field(min_length=0, max_length=1000)
    ingredients: List[RecipeIngredient] = Field(min_length=1, max_length=50)

    @field_validator("name", "description")
    @classmethod
    def strip_strings(cls, v: str) -> str:
        return v.strip()


class RecipeUpdate(BaseModel):
    name: Optional[str] = Field(default=None, max_length=100)
    description: Optional[str] = Field(default=None, max_length=1000)
    ingredients: Optional[List[RecipeIngredient]] = Field(default=None, max_length=50)

    @field_validator("name", "description")
    @classmethod
    def strip_strings(cls, v: Optional[str]) -> Optional[str]:
        return v.strip() if v is not None else v


class MissingIngredient(BaseModel):
    name: str
    required: float
    available: float
    unit: str


class RecipeResponse(BaseModel):
    id: str
    name: str
    description: str
    ingredients: List[RecipeIngredient]
    availability: str = "unavailable"
    missing_ingredients: List[MissingIngredient] = []
