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
        port=int(os.getenv("PORT", "8000")),
        allowed_origins=_split_csv(os.getenv("ALLOWED_ORIGINS", "*")),
    )
