from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from pymongo import ReplaceOne
from pymongo.collection import Collection
from pypdf import PdfReader

from config import Settings
from embeddings import embed_documents


@dataclass(frozen=True)
class Chunk:
    source_file: str
    page: int
    chunk_index: int
    text: str


@dataclass(frozen=True)
class UploadStats:
    deleted_count: int
    uploaded_count: int
    source_file: str


def normalize_whitespace(text: str) -> str:
    return " ".join(text.split())


def chunk_words(text: str, *, chunk_words_count: int, overlap: int) -> list[str]:
    words = text.split()
    if not words:
        return []
    if overlap >= chunk_words_count:
        raise ValueError("UPLOAD_CHUNK_OVERLAP must be smaller than UPLOAD_CHUNK_WORDS.")

    chunks: list[str] = []
    step = chunk_words_count - overlap
    for start in range(0, len(words), step):
        chunk = " ".join(words[start : start + chunk_words_count])
        if chunk:
            chunks.append(chunk)
    return chunks


def extract_chunks(
    pdf_path: Path,
    *,
    source_file: str,
    chunk_words_count: int,
    overlap: int,
) -> list[Chunk]:
    try:
        reader = PdfReader(str(pdf_path))
    except Exception as error:
        raise ValueError(f"Could not read uploaded PDF: {error}") from error

    chunks: list[Chunk] = []
    for page_index, page in enumerate(reader.pages, start=1):
        try:
            text = normalize_whitespace(page.extract_text() or "")
        except Exception as error:
            raise ValueError(f"Could not extract text from PDF page {page_index}: {error}") from error
        for local_index, chunk in enumerate(
            chunk_words(text, chunk_words_count=chunk_words_count, overlap=overlap)
        ):
            chunks.append(
                Chunk(
                    source_file=source_file,
                    page=page_index,
                    chunk_index=local_index,
                    text=chunk,
                )
            )
    return chunks


def stable_chunk_id(isbn: str, chunk: Chunk) -> str:
    raw = f"{isbn}:{chunk.source_file}:{chunk.page}:{chunk.chunk_index}:{chunk.text}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def batched(items: list[Chunk], batch_size: int) -> Iterable[list[Chunk]]:
    for start in range(0, len(items), batch_size):
        yield items[start : start + batch_size]


def build_operations(
    *,
    chunks: list[Chunk],
    embeddings: list[list[float]],
    isbn: str,
    cloudinary_url: str,
    settings: Settings,
) -> list[ReplaceOne]:
    now = datetime.now(timezone.utc)
    operations: list[ReplaceOne] = []
    for chunk, embedding in zip(chunks, embeddings, strict=True):
        document = {
            "_id": stable_chunk_id(isbn, chunk),
            "isbn": isbn,
            "cloudinary_url": cloudinary_url,
            "source_file": chunk.source_file,
            "page": chunk.page,
            "chunk_index": chunk.chunk_index,
            "text": chunk.text,
            "embedding": embedding,
            "model": settings.embedding_model,
            "embedding_dim": settings.embedding_dim,
            "embedding_normalized": True,
            "embedding_role": "document",
            "chunker": {
                "type": "word_window",
                "chunk_words": settings.upload_chunk_words,
                "chunk_overlap": settings.upload_chunk_overlap,
            },
            "created_at": now,
            "updated_at": now,
        }
        operations.append(ReplaceOne({"_id": document["_id"]}, document, upsert=True))
    return operations


def upload_textbook_chunks(
    *,
    collection: Collection,
    pdf_path: Path,
    source_file: str,
    isbn: str,
    cloudinary_url: str,
    settings: Settings,
) -> UploadStats:
    if settings.upload_batch_size < 1:
        raise ValueError("UPLOAD_BATCH_SIZE must be at least 1.")

    chunks = extract_chunks(
        pdf_path,
        source_file=source_file,
        chunk_words_count=settings.upload_chunk_words,
        overlap=settings.upload_chunk_overlap,
    )
    if not chunks:
        raise ValueError("No text chunks were extracted from the uploaded PDF.")

    collection.create_index([("isbn", 1)])
    collection.create_index([("source_file", 1), ("page", 1)])

    delete_result = collection.delete_many({"isbn": isbn})

    uploaded = 0
    for chunk_batch in batched(chunks, settings.upload_batch_size):
        embeddings = embed_documents([chunk.text for chunk in chunk_batch], settings)
        operations = build_operations(
            chunks=chunk_batch,
            embeddings=embeddings,
            isbn=isbn,
            cloudinary_url=cloudinary_url,
            settings=settings,
        )
        if operations:
            collection.bulk_write(operations, ordered=False)
            uploaded += len(operations)

    return UploadStats(
        deleted_count=delete_result.deleted_count,
        uploaded_count=uploaded,
        source_file=source_file,
    )
