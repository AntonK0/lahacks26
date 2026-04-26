from __future__ import annotations

import shutil
from pathlib import Path
from tempfile import NamedTemporaryFile
from urllib.parse import urlparse

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pymongo.errors import PyMongoError

import uvicorn

from config import get_settings
from db import get_collection
from embeddings import embed_query
from models import HealthResponse, RetrievalRequest, RetrievalResponse, TextbookUploadRequest, TextbookUploadResponse
from redis_store import RedisConfigError, RedisUpdateError, set_textbook_config
from textbook_ingestion import upload_textbook_chunks


settings = get_settings()

app = FastAPI(
    title="LA Hacks Backend",
    description="ISBN-scoped query embedding and MongoDB Atlas Vector Search backend for the AR tutor.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "LA Hacks backend is running."}


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok")


def validate_cloudinary_url(value: str) -> str:
    cloudinary_url = value.strip()
    parsed = urlparse(cloudinary_url)
    hostname = parsed.hostname or ""
    if parsed.scheme not in {"http", "https"} or not hostname.endswith("cloudinary.com"):
        raise HTTPException(status_code=400, detail="cloudinary_url must be a valid Cloudinary URL.")
    return cloudinary_url


def validate_pdf_upload(file: UploadFile) -> str:
    filename = Path(file.filename or "").name
    if not filename:
        raise HTTPException(status_code=400, detail="file must include a PDF filename.")
    if Path(filename).suffix.lower() != ".pdf" and file.content_type != "application/pdf":
        raise HTTPException(status_code=400, detail="file must be a PDF upload.")
    return filename


@app.post("/upload-textbook", response_model=TextbookUploadResponse)
def upload_textbook(
    request: TextbookUploadRequest = Depends(TextbookUploadRequest.as_form),
    file: UploadFile = File(...),
) -> TextbookUploadResponse:
    scoped_isbn = request.isbn.strip()
    if not scoped_isbn:
        raise HTTPException(status_code=400, detail="isbn is required for textbook upload.")

    validated_cloudinary_url = validate_cloudinary_url(request.cloudinary_url)
    source_file = validate_pdf_upload(file)

    temp_path: Path | None = None
    try:
        with NamedTemporaryFile(delete=False, suffix=".pdf") as temp_file:
            temp_path = Path(temp_file.name)
            shutil.copyfileobj(file.file, temp_file)

        stats = upload_textbook_chunks(
            collection=get_collection(settings),
            pdf_path=temp_path,
            source_file=source_file,
            isbn=scoped_isbn,
            cloudinary_url=validated_cloudinary_url,
            settings=settings,
        )
        set_textbook_config(scoped_isbn, validated_cloudinary_url, settings)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except PyMongoError as error:
        raise HTTPException(status_code=502, detail=f"MongoDB upload failed: {error}") from error
    except (RedisConfigError, RedisUpdateError) as error:
        raise HTTPException(status_code=502, detail=f"Redis update failed: {error}") from error
    except Exception as error:
        raise HTTPException(status_code=500, detail=f"Textbook upload failed: {error}") from error
    finally:
        file.file.close()
        if temp_path:
            temp_path.unlink(missing_ok=True)

    return TextbookUploadResponse(
        collection=settings.mongodb_collection,
        isbn=scoped_isbn,
        cloudinary_url=validated_cloudinary_url,
        source_file=stats.source_file,
        deleted_count=stats.deleted_count,
        uploaded_count=stats.uploaded_count,
        embedding_model=settings.embedding_model,
        embedding_dim=settings.embedding_dim,
        redis={
            "key": scoped_isbn,
            "fields": {
                "cloudinary_url": validated_cloudinary_url,
                "textbook_id": scoped_isbn,
            },
        },
    )


@app.post("/retrieve-context", response_model=RetrievalResponse)
def retrieve_context(request: RetrievalRequest) -> RetrievalResponse:
    isbn = request.isbn.strip()
    if not isbn:
        raise HTTPException(status_code=400, detail="isbn is required for scoped textbook retrieval.")
    message = request.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="message is required for retrieval.")

    try:
        query_vector = embed_query(message, settings)
    except Exception as error:
        raise HTTPException(status_code=500, detail=f"Query embedding failed: {error}") from error

    num_candidates = request.num_candidates or max(request.limit * 10, 50)
    vector_search = {
        "index": settings.mongodb_vector_index,
        "path": "embedding",
        "queryVector": query_vector,
        "numCandidates": min(max(num_candidates, request.limit), 200),
        "limit": request.limit,
        "filter": {"isbn": isbn},
    }

    try:
        chunks = list(
            get_collection(settings).aggregate(
                [
                    {"$vectorSearch": vector_search},
                    {
                        "$project": {
                            "_id": 0,
                            "text": 1,
                            "isbn": 1,
                            "source_file": 1,
                            "page": 1,
                            "chunk_index": 1,
                            "score": {"$meta": "vectorSearchScore"},
                        }
                    },
                ]
            )
        )
    except PyMongoError as error:
        raise HTTPException(status_code=502, detail=f"MongoDB query failed: {error}") from error

    return RetrievalResponse(
        collection=settings.mongodb_collection,
        index=settings.mongodb_vector_index,
        isbn=isbn,
        count=len(chunks),
        chunks=chunks,
    )


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=settings.port, reload=True)
