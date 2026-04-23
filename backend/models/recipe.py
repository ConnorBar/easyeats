from pydantic import BaseModel
from typing import Optional, List


class RecipeIngredient(BaseModel):
    ingredientId: str
    name: str
    quantity: float
    unit: str


class RecipeCreate(BaseModel):
    name: str
    description: str
    ingredients: List[RecipeIngredient]


class RecipeUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    ingredients: Optional[List[RecipeIngredient]] = None


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
