from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv


load_dotenv()


@dataclass(frozen=True)
class Settings:
    mongodb_uri: str
    mongodb_db: str
    mongodb_collection: str
    mongodb_vector_index: str
    embedding_model: str
    embedding_dim: int
    upload_chunk_words: int
    upload_chunk_overlap: int
    upload_batch_size: int
    port: int
    allowed_origins: list[str]


def _split_csv(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def get_settings() -> Settings:
    mongodb_uri = os.getenv("MONGODB_URI")
    if not mongodb_uri:
        raise RuntimeError("MONGODB_URI is required.")

    return Settings(
        mongodb_uri=mongodb_uri,
        mongodb_db=os.getenv("MONGODB_DB", "lahacks"),
        mongodb_collection=os.getenv("MONGODB_COLLECTION", "textbook_chunks"),
        mongodb_vector_index=os.getenv("MONGODB_VECTOR_INDEX", "textbook_chunks_vector_index"),
        embedding_model=os.getenv("EMBEDDING_MODEL", "google/embeddinggemma-300m"),
        embedding_dim=int(os.getenv("EMBEDDING_DIM", "768")),
        upload_chunk_words=int(os.getenv("UPLOAD_CHUNK_WORDS", "320")),
        upload_chunk_overlap=int(os.getenv("UPLOAD_CHUNK_OVERLAP", "60")),
        upload_batch_size=int(os.getenv("UPLOAD_BATCH_SIZE", "64")),
        port=int(os.getenv("PORT", "8000")),
        allowed_origins=_split_csv(os.getenv("ALLOWED_ORIGINS", "*")),
    )
