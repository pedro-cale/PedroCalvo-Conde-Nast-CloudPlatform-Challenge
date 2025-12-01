from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

@app.get("/")
async def root():
    return "Hello World and Condé Nast team!"

# Optional health check for ALB/ECS
@app.get("/health")
async def health():
    return {"status": "ok"}