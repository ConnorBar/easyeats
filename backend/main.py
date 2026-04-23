from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import inventory, recipes, report

app = FastAPI(title="FridgeBridge API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(inventory.router)
app.include_router(recipes.router)
app.include_router(report.router)


@app.get("/")
async def root():
    return {"message": "FridgeBridge API is running"}
