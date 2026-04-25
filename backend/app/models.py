from __future__ import annotations

from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field


class RetrievalRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    isbn: Annotated[str, Field(min_length=1)]
    query_vector: Annotated[
        list[float],
        Field(alias="queryVector", min_length=768, max_length=768),
    ]
    textbook_id: str | None = None
    limit: Annotated[int, Field(ge=1, le=10)] = 5
    num_candidates: Annotated[
        int | None,
        Field(alias="numCandidates", ge=1, le=200),
    ] = None


class RetrievedChunk(BaseModel):
    text: str
    isbn: str | None = None
    textbook_id: str | None = None
    source_file: str | None = None
    page: int | None = None
    chunk_index: int | None = None
    score: float | None = None


class RetrievalResponse(BaseModel):
    collection: str
    index: str
    isbn: str
    count: int
    chunks: list[RetrievedChunk]


class HealthResponse(BaseModel):
    status: str
