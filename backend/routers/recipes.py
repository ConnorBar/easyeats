from fastapi import APIRouter, HTTPException
from bson import ObjectId
from pymongo import ReturnDocument

from database import recipes_collection, inventory_collection
from models.recipe import RecipeCreate, RecipeUpdate, RecipeResponse
from services.availability import compute_availability

router = APIRouter(prefix="/recipes", tags=["recipes"])


def _doc_to_dict(doc: dict) -> dict:
    return {
        "id": str(doc["_id"]),
        "name": doc["name"],
        "description": doc["description"],
        "ingredients": doc.get("ingredients", []),
    }


async def _build_inventory_map() -> dict:
    """Build a lookup map of str(inventory_id) -> inventory document.
    Computes total quantity from batches for availability checks."""
    inv_map = {}
    async for item in inventory_collection.find():
        batches = item.get("batches", [])
        if not batches:
            batches = [{"quantity": item.get("quantity", 0)}]
        item["quantity"] = sum(b.get("quantity", 0) for b in batches)
        inv_map[str(item["_id"])] = item
    return inv_map


async def _enrich_recipe(doc: dict) -> dict:
    """Attach availability status and missing_ingredients to a recipe dict."""
    inv_map = await _build_inventory_map()
    recipe_dict = _doc_to_dict(doc)
    status, missing = compute_availability(recipe_dict, inv_map)
    recipe_dict["availability"] = status
    recipe_dict["missing_ingredients"] = missing
    return recipe_dict


# DYNAMIC FROM DB: Lists all recipes with availability computed live from
# current inventory state. No hardcoded status values — everything is derived
# from the actual MongoDB inventory documents at request time.
@router.get("", response_model=list[RecipeResponse])
async def list_recipes():
    inv_map = await _build_inventory_map()
    recipes = []
    async for doc in recipes_collection.find():
        recipe_dict = _doc_to_dict(doc)
        status, missing = compute_availability(recipe_dict, inv_map)
        recipe_dict["availability"] = status
        recipe_dict["missing_ingredients"] = missing
        recipes.append(recipe_dict)
    return recipes


# DYNAMIC FROM DB: Writes ingredientId references that point to real inventory
# _id values. The client sends ingredientId strings obtained from GET /inventory;
# these are stored in the recipe document so availability checks can resolve them.
@router.post("", response_model=RecipeResponse, status_code=201)
async def add_recipe(recipe: RecipeCreate):
    doc = recipe.model_dump()
    result = await recipes_collection.insert_one(doc)
    doc["_id"] = result.inserted_id
    return await _enrich_recipe(doc)


# DYNAMIC FROM DB: Same ingredientId reference logic as POST — updated
# ingredient rows carry live inventory _id references.
@router.put("/{recipe_id}", response_model=RecipeResponse)
async def update_recipe(recipe_id: str, recipe: RecipeUpdate):
    if not ObjectId.is_valid(recipe_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    update_data = {k: v for k, v in recipe.model_dump().items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")
    result = await recipes_collection.find_one_and_update(
        {"_id": ObjectId(recipe_id)},
        {"$set": update_data},
        return_document=ReturnDocument.AFTER,
    )
    if not result:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return await _enrich_recipe(result)


@router.delete("/{recipe_id}", status_code=204)
async def delete_recipe(recipe_id: str):
    if not ObjectId.is_valid(recipe_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    result = await recipes_collection.delete_one({"_id": ObjectId(recipe_id)})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Recipe not found")


@router.post("/{recipe_id}/complete", response_model=RecipeResponse)
async def complete_recipe(recipe_id: str):
    if not ObjectId.is_valid(recipe_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    doc = await recipes_collection.find_one({"_id": ObjectId(recipe_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Recipe not found")

    for ing in doc.get("ingredients", []):
        if not ObjectId.is_valid(ing.get("ingredientId", "")):
            continue
        inv_doc = await inventory_collection.find_one(
            {"_id": ObjectId(ing["ingredientId"])}
        )
        if not inv_doc:
            continue

        batches = inv_doc.get("batches", [])
        if not batches:
            batches = [
                {
                    "quantity": inv_doc.get("quantity", 0),
                    "expireDate": inv_doc.get("expireDate"),
                }
            ]

        # FIFO: deduct from soonest-expiring batches first
        batches.sort(key=lambda b: b.get("expireDate") or "9999-99-99")

        remaining = ing["quantity"]
        for batch in batches:
            if remaining <= 0:
                break
            deduct = min(batch["quantity"], remaining)
            batch["quantity"] = round(batch["quantity"] - deduct, 4)
            remaining = round(remaining - deduct, 4)

        batches = [b for b in batches if b["quantity"] > 0]

        await inventory_collection.update_one(
            {"_id": inv_doc["_id"]},
            {"$set": {"batches": batches}},
        )

    return await _enrich_recipe(doc)
