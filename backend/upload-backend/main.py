import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, constr
import redis

app = FastAPI(title="Upload Backend API")

# Allow all origins for now. Update this for production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Use the full Redis URL from environment or the default provided by user
REDIS_URL = os.getenv(
    "REDIS_URL",
    "redis://default:kzCqjkZEEp79AyqjmP3oOivR8L68BsnS@redis-13872.c289.us-west-1-2.ec2.cloud.redislabs.com:13872"
)

try:
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)
    # Test connection
    redis_client.ping()
    print("Successfully connected to Redis!")
except Exception as e:
    print(f"Error connecting to Redis: {e}")

class UploadRequest(BaseModel):
    isbn: constr(pattern=r'^\d{13}$')
    cloudinary_url: str

@app.post("/api/upload")
async def upload_model_link(request: UploadRequest):
    try:
        redis_key = f"ISBN:{request.isbn}"
        # Set the key to the cloudinary URL
        redis_client.set(redis_key, request.cloudinary_url)
        return {"message": "Successfully saved to Redis", "isbn": request.isbn, "url": request.cloudinary_url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/health")
async def health_check():
    return {"status": "ok"}
