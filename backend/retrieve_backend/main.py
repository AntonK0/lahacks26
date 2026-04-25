from __future__ import annotations

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pymongo.errors import PyMongoError

import uvicorn

try:
    from retrieve_backend.config import get_settings
    from retrieve_backend.db import get_collection
    from retrieve_backend.models import HealthResponse, RetrievalRequest, RetrievalResponse
except ModuleNotFoundError:
    from config import get_settings
    from db import get_collection
    from models import HealthResponse, RetrievalRequest, RetrievalResponse


settings = get_settings()

app = FastAPI(
    title="LA Hacks Retrieval Backend",
    description="ISBN-scoped MongoDB Atlas Vector Search backend for the AR tutor.",
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
    return {"message": "LA Hacks retrieval backend is running."}


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok")


@app.post("/retrieve-context", response_model=RetrievalResponse)
def retrieve_context(request: RetrievalRequest) -> RetrievalResponse:
    isbn = request.isbn.strip()
    if not isbn:
        raise HTTPException(status_code=400, detail="isbn is required for scoped textbook retrieval.")
    query_vector = [float(value) for value in request.query_vector]
    if not all(value == value and value not in (float("inf"), float("-inf")) for value in query_vector):
        raise HTTPException(status_code=400, detail="queryVector contains non-finite values.")

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
    module_path = "retrieve_backend.main:app" if __package__ else "main:app"
    uvicorn.run(module_path, host="0.0.0.0", port=settings.port, reload=True)
