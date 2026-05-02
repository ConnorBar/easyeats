from fastapi import APIRouter, Query
from pydantic import BaseModel
from typing import Optional, List

from bson import ObjectId
from database import recipes_collection, inventory_collection
from services.availability import compute_availability

router = APIRouter(prefix="/report", tags=["report"])


# ── Shopping list (meal-plan) endpoint ──────────────────────────

class MealPlanItem(BaseModel):
    recipe_id: str
    portions: int = 1


class MealPlanRequest(BaseModel):
    items: List[MealPlanItem]


# DYNAMIC FROM DB: Aggregates ingredient requirements across the selected
# recipes, multiplied by portions, and compares against live inventory to
# produce a shopping list. Nothing is hardcoded.
@router.post("/shopping-list")
async def shopping_list(request: MealPlanRequest):
    # Build inventory lookup: ingredientId (str) -> doc (with total qty)
    inv_map: dict = {}
    async for item in inventory_collection.find():
        batches = item.get("batches", [])
        if not batches:
            batches = [{"quantity": item.get("quantity", 0)}]
        item["quantity"] = sum(b.get("quantity", 0) for b in batches)
        inv_map[str(item["_id"])] = item

    # Aggregate required quantities across all selected recipes * portions.
    # Key: ingredientId -> {name, unit, required}
    agg: dict[str, dict] = {}
    selected_recipes: list[dict] = []

    for entry in request.items:
        if entry.portions <= 0:
            continue
        """ makes sure objectid is valid with our mongo """
        if not ObjectId.is_valid(entry.recipe_id):
            continue
        """ makes sure objectid is valid with our mongo """
        doc = await recipes_collection.find_one({"_id": ObjectId(entry.recipe_id)})
        if not doc:
            continue

        selected_recipes.append({
            "id": str(doc["_id"]),
            "name": doc["name"],
            "portions": entry.portions,
        })

        for ing in doc.get("ingredients", []):
            iid = ing["ingredientId"]
            qty_needed = ing["quantity"] * entry.portions
            if iid in agg:
                agg[iid]["required"] += qty_needed
            else:
                agg[iid] = {
                    "ingredientId": iid,
                    "name": ing["name"],
                    "unit": ing["unit"],
                    "required": qty_needed,
                }

    # Compare against inventory
    shopping: list[dict] = []
    for iid, info in agg.items():
        inv = inv_map.get(iid)
        available = inv["quantity"] if inv else 0
        to_buy = max(0.0, info["required"] - available)
        shopping.append({
            "name": info["name"],
            "unit": info["unit"],
            "required": round(info["required"], 2),
            "available": round(available, 2),
            "to_buy": round(to_buy, 2),
        })

    # Sort: items you need to buy first, then alphabetical
    shopping.sort(key=lambda x: (-x["to_buy"], x["name"]))

    return {
        "recipes": selected_recipes,
        "ingredients": shopping,
    }


# ── Original filter/stats report  ─────

@router.get("/recipes")
async def recipe_report(
    availability: Optional[str] = Query(None, max_length=100, description="Comma-separated statuses"),
    ingredients: Optional[str] = Query(None, max_length=500, description="Comma-separated ingredient names"),
    min_ingredients: Optional[int] = Query(None, ge=0, le=100, description="Minimum ingredient count"),
):
    inv_map: dict = {}
    async for item in inventory_collection.find():
        batches = item.get("batches", [])
        if not batches:
            batches = [{"quantity": item.get("quantity", 0)}]
        item["quantity"] = sum(b.get("quantity", 0) for b in batches)
        inv_map[str(item["_id"])] = item

    status_filter: set[str] = set()
    if availability:
        status_filter = {s.strip() for s in availability.split(",")}

    ingredient_filter: set[str] = set()
    if ingredients:
        ingredient_filter = {n.strip().lower() for n in ingredients.split(",")}

    all_recipes: list[dict] = []
    async for doc in recipes_collection.find():
        recipe_dict = {
            "id": str(doc["_id"]),
            "name": doc["name"],
            "description": doc["description"],
            "ingredients": doc.get("ingredients", []),
        }
        status, missing = compute_availability(recipe_dict, inv_map)
        recipe_dict["availability"] = status
        recipe_dict["missing_ingredients"] = missing
        all_recipes.append(recipe_dict)

    filtered = all_recipes
    if status_filter:
        filtered = [r for r in filtered if r["availability"] in status_filter]
    if ingredient_filter:
        filtered = [
            r for r in filtered
            if any(ing["name"].lower() in ingredient_filter for ing in r["ingredients"])
        ]
    if min_ingredients is not None:
        filtered = [r for r in filtered if len(r["ingredients"]) >= min_ingredients]

    total = len(filtered)
    by_status = {"available": 0, "partial": 0, "unavailable": 0}
    ingredient_counter: dict[str, int] = {}
    total_ingredient_count = 0

    for r in filtered:
        by_status[r["availability"]] = by_status.get(r["availability"], 0) + 1
        total_ingredient_count += len(r["ingredients"])
        for ing in r["ingredients"]:
            ingredient_counter[ing["name"]] = ingredient_counter.get(ing["name"], 0) + 1

    avg_ingredient_count = total_ingredient_count / total if total > 0 else 0
    pct_available = (by_status["available"] / total * 100) if total > 0 else 0
    most_common = {"name": "", "count": 0}
    if ingredient_counter:
        mc_name = max(ingredient_counter, key=ingredient_counter.get)  # type: ignore[arg-type]
        most_common = {"name": mc_name, "count": ingredient_counter[mc_name]}

    return {
        "recipes": filtered,
        "stats": {
            "total": total,
            "by_status": by_status,
            "avg_ingredient_count": round(avg_ingredient_count, 1),
            "most_common_ingredient": most_common,
            "pct_available": round(pct_available, 1),
        },
    }
