from __future__ import annotations

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pymongo.errors import PyMongoError

import uvicorn

from config import get_settings
from db import get_collection
from embeddings import embed_query
from models import HealthResponse, RetrievalRequest, RetrievalResponse


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
