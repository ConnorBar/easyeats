from fastapi import APIRouter, HTTPException
from bson import ObjectId
from pymongo import ReturnDocument

from database import inventory_collection
from models.inventory import (
    Batch,
    InventoryItemCreate,
    InventoryItemUpdate,
    InventoryItemResponse,
)

router = APIRouter(prefix="/inventory", tags=["inventory"])


def _normalise_batches(doc: dict) -> list[dict]:
    """Return the batches array, migrating legacy single-qty docs on the fly."""
    batches = doc.get("batches")
    if batches:
        return batches
    qty = doc.get("quantity", 0)
    exp = doc.get("expireDate")
    if qty or exp:
        return [{"quantity": qty, "expireDate": exp}]
    return []


def _doc_to_response(doc: dict) -> dict:
    batches = _normalise_batches(doc)
    total_qty = sum(b.get("quantity", 0) for b in batches)
    dates = [
        b["expireDate"]
        for b in batches
        if b.get("expireDate") and b.get("quantity", 0) > 0
    ]
    soonest = min(dates) if dates else None

    return {
        "id": str(doc["_id"]),
        "name": doc["name"],
        "quantity": round(total_qty, 4),
        "unit": doc["unit"],
        "expireDate": soonest,
        "batches": batches,
        "priceHistory": doc.get("priceHistory", []),
    }


@router.get("", response_model=list[InventoryItemResponse])
async def list_inventory():
    items = []
    async for doc in inventory_collection.find():
        items.append(_doc_to_response(doc))
    return items


@router.post("", response_model=InventoryItemResponse, status_code=201)
async def add_inventory_item(item: InventoryItemCreate):
    # Only create an initial batch when quantity > 0.
    # quantity=0 is used by the recipe sheet to register a placeholder ingredient
    # that doesn't exist in the pantry yet; no batch means availability correctly
    # reports it as missing rather than present-with-zero-stock.
    initial_batches = (
        [{"quantity": item.quantity, "expireDate": item.expireDate}]
        if item.quantity > 0
        else []
    )
    doc = {
        "name": item.name,
        "unit": item.unit,
        "batches": initial_batches,
        "priceHistory": [e.model_dump() for e in item.priceHistory],
    }
    result = await inventory_collection.insert_one(doc)
    doc["_id"] = result.inserted_id
    return _doc_to_response(doc)


@router.put("/{item_id}", response_model=InventoryItemResponse)
async def update_inventory_item(item_id: str, item: InventoryItemUpdate):
    """ makes sure objectid is valid with our mongo """
    if not ObjectId.is_valid(item_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    """ makes sure objectid is valid with our mongo """

    update_data: dict = {}
    if item.name is not None:
        update_data["name"] = item.name
    if item.unit is not None:
        update_data["unit"] = item.unit
    if item.batches is not None:
        update_data["batches"] = [b.model_dump() for b in item.batches]
    if item.priceHistory is not None:
        update_data["priceHistory"] = [e.model_dump() for e in item.priceHistory]

    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    result = await inventory_collection.find_one_and_update(
        {"_id": ObjectId(item_id)},
        {"$set": update_data},
        return_document=ReturnDocument.AFTER,
    )
    if not result:
        raise HTTPException(status_code=404, detail="Item not found")
    return _doc_to_response(result)


@router.post("/{item_id}/batch", response_model=InventoryItemResponse)
async def add_batch(item_id: str, batch: Batch):
    """Append a new batch to an existing inventory item."""
    """ makes sure objectid is valid with our mongo """
    if not ObjectId.is_valid(item_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    """ makes sure objectid is valid with our mongo """

    # Migrate legacy docs first
    existing = await inventory_collection.find_one({"_id": ObjectId(item_id)})
    if not existing:
        raise HTTPException(status_code=404, detail="Item not found")

    if "batches" not in existing or existing["batches"] is None:
        legacy = _normalise_batches(existing)
        await inventory_collection.update_one(
            {"_id": ObjectId(item_id)},
            {"$set": {"batches": legacy}},
        )

    result = await inventory_collection.find_one_and_update(
        {"_id": ObjectId(item_id)},
        {"$push": {"batches": batch.model_dump()}},
        return_document=ReturnDocument.AFTER,
    )
    return _doc_to_response(result)


@router.delete("/{item_id}", status_code=204)
async def delete_inventory_item(item_id: str):
    if not ObjectId.is_valid(item_id):
        raise HTTPException(status_code=400, detail="Invalid ID")
    result = await inventory_collection.delete_one({"_id": ObjectId(item_id)})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Item not found")
