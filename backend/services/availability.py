from typing import Tuple, List, Dict, Any


def compute_availability(
    recipe: Dict[str, Any],
    inventory_map: Dict[str, Dict[str, Any]],
) -> Tuple[str, List[Dict[str, Any]]]:
    """
    Pure function: recipe dict + inventory lookup map -> (status, missing_ingredients).

    Status rules:
      available   - every ingredient is in stock at the required quantity
      partial     - all ingredients exist but >=1 is short by <=50%,
                    OR at most 1 ingredient is completely missing
                    (and no present ingredient is short by >50%)
      unavailable - anything else

    # TODO: Unit normalisation is not implemented. Comparisons assume the
    #       recipe and inventory use the same unit for a given ingredient.
    """
    missing: List[Dict[str, Any]] = []
    completely_missing_count = 0
    any_over_half_short = False

    for ing in recipe.get("ingredients", []):
        inv = inventory_map.get(ing["ingredientId"])

        if inv is None:
            completely_missing_count += 1
            missing.append({
                "name": ing["name"],
                "required": ing["quantity"],
                "available": 0,
                "unit": ing["unit"],
            })
        elif inv["quantity"] < ing["quantity"]:
            shortfall_pct = (
                (ing["quantity"] - inv["quantity"]) / ing["quantity"]
                if ing["quantity"] > 0
                else 1.0
            )
            if shortfall_pct > 0.5:
                any_over_half_short = True
            missing.append({
                "name": ing["name"],
                "required": ing["quantity"],
                "available": inv["quantity"],
                "unit": ing["unit"],
            })

    if not missing:
        return "available", []

    if not any_over_half_short and completely_missing_count <= 1:
        return "partial", missing

    return "unavailable", missing
