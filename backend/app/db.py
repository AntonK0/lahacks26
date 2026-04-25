from __future__ import annotations

from functools import lru_cache

from pymongo import MongoClient
from pymongo.collection import Collection

from app.config import Settings, get_settings


@lru_cache(maxsize=1)
def get_client() -> MongoClient:
    settings = get_settings()
    # Same core pattern as MongoDB's Python starter: create one MongoClient
    # from the Atlas connection string and reuse it across requests.
    return MongoClient(settings.mongodb_uri)


def get_collection(settings: Settings | None = None) -> Collection:
    active_settings = settings or get_settings()
    return get_client()[active_settings.mongodb_db][active_settings.mongodb_collection]
