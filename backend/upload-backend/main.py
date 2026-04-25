import os
import re
from fastapi import FastAPI, HTTPException, Form, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
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
    "REDIS_URL"
)

try:
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)
    # Test connection
    redis_client.ping()
    print("Successfully connected to Redis!")
except Exception as e:
    print(f"Error connecting to Redis: {e}")

@app.post("/api/upload")
async def upload_model_link(
    isbn: str = Form(...),
    cloudinary_url: str = Form(...),
    textbook_id: str = Form(None),
    pdf_file: UploadFile = File(None)
):
    if not re.match(r'^\d{13}$', isbn):
        raise HTTPException(status_code=400, detail="ISBN must be 13 digits")
        
    try:
        redis_key = f"ISBN:{isbn}"
        # Set the key to the cloudinary URL
        redis_client.set(redis_key, cloudinary_url)
        
        return {
            "message": "Successfully saved textbook metadata to Redis",
            "isbn": isbn, 
            "url": cloudinary_url,
            "textbook_id": textbook_id,
            "pdf_uploaded": pdf_file is not None,
            "pdf_filename": pdf_file.filename if pdf_file else None,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/health")
async def health_check():
    return {"status": "ok"}
