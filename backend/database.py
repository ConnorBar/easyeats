import os
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
from pymongo import ASCENDING, TEXT

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
DATABASE_NAME = os.getenv("DATABASE_NAME", "fridgebridge")

client = AsyncIOMotorClient(MONGODB_URI)
db = client[DATABASE_NAME]

inventory_collection = db["inventory"]
recipes_collection = db["recipes"]


async def create_indexes():
    """
    Create indexes to support key queries and reports.

    Index 1: inventory.name (ASCENDING)
      - Supports: GET /report/recipes?ingredients=... which filters recipes
        by ingredient name, and GET /inventory which scans all items.
      - Also supports deduplication checks when adding inventory items.

    Index 2: inventory.batches.expireDate (ASCENDING)
      - Supports: POST /recipes/{id}/complete which sorts batches by expireDate
        for FIFO deduction. Speeds up range queries on expiry dates.

    Index 3: recipes.name (TEXT index)
      - Supports: GET /report/recipes which returns all recipes — a text index
        allows future name-based search without a full collection scan.
      - Also supports GET /recipes listing, where names are displayed/sorted.
    """
    # Index 1: inventory name lookup (used in report ingredient filter)
    await inventory_collection.create_index(
        [("name", ASCENDING)],
        name="idx_inventory_name"
    )

    # Index 2: batch expiry date (used in FIFO deduction in complete_recipe)
    await inventory_collection.create_index(
        [("batches.expireDate", ASCENDING)],
        name="idx_inventory_batch_expireDate"
    )

    # Index 3: recipe name text search (supports report and listing)
    await recipes_collection.create_index(
        [("name", TEXT)],
        name="idx_recipes_name_text"
    )
