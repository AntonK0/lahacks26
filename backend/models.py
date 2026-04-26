from __future__ import annotations

from typing import Annotated

from fastapi import Form
from pydantic import BaseModel, ConfigDict, Field


class RetrievalRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    isbn: Annotated[str, Field(min_length=1)]
    message: Annotated[str, Field(min_length=1, max_length=4000)]
    limit: Annotated[int, Field(ge=1, le=10)] = 5
    num_candidates: Annotated[
        int | None,
        Field(alias="numCandidates", ge=1, le=200),
    ] = None


class RetrievedChunk(BaseModel):
    text: str
    isbn: str | None = None
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


class TextbookUploadRequest(BaseModel):
    isbn: Annotated[str, Field(min_length=1)]
    cloudinary_url: Annotated[str, Field(min_length=1)]

    @classmethod
    def as_form(
        cls,
        isbn: str = Form(...),
        cloudinary_url: str = Form(...),
    ) -> TextbookUploadRequest:
        return cls(isbn=isbn, cloudinary_url=cloudinary_url)


class RedisSyncInfo(BaseModel):
    key: str
    fields: dict[str, str]


class TextbookUploadResponse(BaseModel):
    collection: str
    isbn: str
    cloudinary_url: str
    source_file: str
    deleted_count: int
    uploaded_count: int
    embedding_model: str
    embedding_dim: int
    redis: RedisSyncInfo


class HealthResponse(BaseModel):
    status: str
