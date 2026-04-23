import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
DATABASE_NAME = os.getenv("DATABASE_NAME", "fridgebridge")

client = AsyncIOMotorClient(MONGODB_URI)
db = client[DATABASE_NAME]

inventory_collection = db["inventory"]
recipes_collection = db["recipes"]
