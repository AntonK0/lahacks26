from __future__ import annotations

import math
from functools import lru_cache
from typing import Iterable

from sentence_transformers import SentenceTransformer

from config import Settings, get_settings


@lru_cache(maxsize=1)
def get_embedding_model(model_name: str) -> SentenceTransformer:
    return SentenceTransformer(model_name)


def normalize_vector(vector: list[float]) -> list[float]:
    magnitude = math.sqrt(sum(value * value for value in vector))
    if magnitude == 0:
        raise ValueError("Embedding model returned a zero vector.")
    return [value / magnitude for value in vector]


def truncate_and_normalize(vector: Iterable[float], dimensions: int) -> list[float]:
    values = [float(value) for value in vector]
    if len(values) < dimensions:
        raise ValueError(f"Embedding has {len(values)} dimensions, expected at least {dimensions}.")
    if not all(value == value and value not in (float("inf"), float("-inf")) for value in values):
        raise ValueError("Embedding model returned non-finite values.")
    return normalize_vector(values[:dimensions])


def embed_query(message: str, settings: Settings | None = None) -> list[float]:
    active_settings = settings or get_settings()
    model = get_embedding_model(active_settings.embedding_model)
    embedding = model.encode_query(
        [message],
        normalize_embeddings=True,
        convert_to_numpy=True,
        show_progress_bar=False,
    )[0]
    return truncate_and_normalize(embedding.tolist(), active_settings.embedding_dim)


def embed_documents(texts: list[str], settings: Settings | None = None) -> list[list[float]]:
    active_settings = settings or get_settings()
    if active_settings.document_embedding_batch_size < 1:
        raise ValueError("DOCUMENT_EMBEDDING_BATCH_SIZE must be at least 1.")

    model = get_embedding_model(active_settings.embedding_model)
    embeddings = model.encode_document(
        texts,
        batch_size=min(active_settings.document_embedding_batch_size, max(1, len(texts))),
        normalize_embeddings=True,
        convert_to_numpy=True,
        show_progress_bar=False,
    )
    return [
        truncate_and_normalize(embedding.tolist(), active_settings.embedding_dim)
        for embedding in embeddings
    ]
