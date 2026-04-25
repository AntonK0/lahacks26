from __future__ import annotations

import argparse
import hashlib
import math
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from dotenv import load_dotenv
from pymongo import MongoClient, ReplaceOne
from pypdf import PdfReader
from sentence_transformers import SentenceTransformer
from tqdm import tqdm


DEFAULT_MODEL = "google/embeddinggemma-300m"
DEFAULT_CHUNK_WORDS = 320
DEFAULT_CHUNK_OVERLAP = 60
DEFAULT_EMBEDDING_DIM = 768


@dataclass(frozen=True)
class Chunk:
    source_file: str
    page: int
    chunk_index: int
    text: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Parse textbook PDFs, embed chunks with EmbeddingGemma, and upload them to MongoDB Atlas."
    )
    parser.add_argument("pdfs", nargs="*", type=Path, help="PDF files to ingest.")
    parser.add_argument("--pdf-dir", type=Path, help="Directory containing PDFs to ingest.")
    parser.add_argument("--textbook-id", default=os.getenv("TEXTBOOK_ID"), help="Stable textbook routing id.")
    parser.add_argument("--isbn", default=os.getenv("ISBN") or None, help="Required ISBN routing key.")
    parser.add_argument("--mongodb-uri", default=os.getenv("MONGODB_URI"), help="MongoDB Atlas connection string.")
    parser.add_argument("--db", default=os.getenv("MONGODB_DB", "lahacks"), help="MongoDB database name.")
    parser.add_argument(
        "--collection",
        default=os.getenv("MONGODB_COLLECTION", "textbook_chunks"),
        help="MongoDB collection name.",
    )
    parser.add_argument(
        "--model",
        default=os.getenv("EMBEDDING_MODEL", DEFAULT_MODEL),
        help="Sentence Transformers model id.",
    )
    parser.add_argument(
        "--embedding-dim",
        type=int,
        default=int(os.getenv("EMBEDDING_DIM", DEFAULT_EMBEDDING_DIM)),
        choices=(128, 256, 512, 768),
        help="Stored embedding dimensions. Use 768 unless the iOS query model truncates the same way.",
    )
    parser.add_argument("--chunk-words", type=int, default=DEFAULT_CHUNK_WORDS)
    parser.add_argument("--chunk-overlap", type=int, default=DEFAULT_CHUNK_OVERLAP)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument(
        "--replace-textbook",
        action="store_true",
        help="Delete existing chunks for this ISBN before uploading new chunks.",
    )
    return parser.parse_args()


def discover_pdfs(paths: Iterable[Path], pdf_dir: Path | None) -> list[Path]:
    pdfs = [path for path in paths if path.suffix.lower() == ".pdf"]
    if pdf_dir:
        pdfs.extend(sorted(pdf_dir.glob("*.pdf")))
    unique = sorted({path.resolve() for path in pdfs})
    if not unique:
        raise ValueError("No PDF files found. Pass PDF paths or --pdf-dir.")
    return unique


def normalize_whitespace(text: str) -> str:
    return " ".join(text.split())


def chunk_words(text: str, *, chunk_words_count: int, overlap: int) -> list[str]:
    words = text.split()
    if not words:
        return []
    if overlap >= chunk_words_count:
        raise ValueError("--chunk-overlap must be smaller than --chunk-words.")

    chunks: list[str] = []
    step = chunk_words_count - overlap
    for start in range(0, len(words), step):
        chunk = " ".join(words[start : start + chunk_words_count])
        if chunk:
            chunks.append(chunk)
    return chunks


def extract_chunks(pdf_path: Path, *, chunk_words_count: int, overlap: int) -> list[Chunk]:
    reader = PdfReader(str(pdf_path))
    chunks: list[Chunk] = []
    for page_index, page in enumerate(reader.pages, start=1):
        text = normalize_whitespace(page.extract_text() or "")
        for local_index, chunk in enumerate(
            chunk_words(text, chunk_words_count=chunk_words_count, overlap=overlap)
        ):
            chunks.append(
                Chunk(
                    source_file=pdf_path.name,
                    page=page_index,
                    chunk_index=local_index,
                    text=chunk,
                )
            )
    return chunks


def stable_chunk_id(isbn: str, chunk: Chunk) -> str:
    raw = f"{isbn}:{chunk.source_file}:{chunk.page}:{chunk.chunk_index}:{chunk.text}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def normalize_vector(vector: list[float]) -> list[float]:
    magnitude = math.sqrt(sum(value * value for value in vector))
    if magnitude == 0:
        raise ValueError("Embedding model returned a zero vector.")
    return [value / magnitude for value in vector]


def truncate_and_normalize(vector: Iterable[float], dimensions: int) -> list[float]:
    values = [float(value) for value in vector]
    if len(values) < dimensions:
        raise ValueError(f"Embedding has {len(values)} dimensions, expected at least {dimensions}.")
    return normalize_vector(values[:dimensions])


def embed_documents(model: SentenceTransformer, texts: list[str], dimensions: int) -> list[list[float]]:
    embeddings = model.encode_document(
        texts,
        batch_size=min(32, max(1, len(texts))),
        normalize_embeddings=True,
        convert_to_numpy=True,
        show_progress_bar=False,
    )
    return [truncate_and_normalize(row.tolist(), dimensions) for row in embeddings]


def batched(items: list[Chunk], batch_size: int) -> Iterable[list[Chunk]]:
    for start in range(0, len(items), batch_size):
        yield items[start : start + batch_size]


def build_operations(
    *,
    chunks: list[Chunk],
    embeddings: list[list[float]],
    textbook_id: str,
    isbn: str,
    model_name: str,
    embedding_dim: int,
    chunk_words_count: int,
    chunk_overlap: int,
) -> list[ReplaceOne]:
    now = datetime.now(timezone.utc)
    operations: list[ReplaceOne] = []
    for chunk, embedding in zip(chunks, embeddings, strict=True):
        document = {
            "_id": stable_chunk_id(isbn, chunk),
            "textbook_id": textbook_id,
            "isbn": isbn,
            "source_file": chunk.source_file,
            "page": chunk.page,
            "chunk_index": chunk.chunk_index,
            "text": chunk.text,
            "embedding": embedding,
            "model": model_name,
            "embedding_dim": embedding_dim,
            "embedding_normalized": True,
            "embedding_role": "document",
            "chunker": {
                "type": "word_window",
                "chunk_words": chunk_words_count,
                "chunk_overlap": chunk_overlap,
            },
            "created_at": now,
            "updated_at": now,
        }
        operations.append(ReplaceOne({"_id": document["_id"]}, document, upsert=True))
    return operations


def main() -> None:
    load_dotenv()
    args = parse_args()

    if not args.mongodb_uri:
        raise ValueError("MONGODB_URI is required. Set it in ingestion/.env or pass --mongodb-uri.")
    if not args.textbook_id:
        raise ValueError("TEXTBOOK_ID is required. Set it in ingestion/.env or pass --textbook-id.")
    if not args.isbn:
        raise ValueError("ISBN is required. Set it in ingestion/.env or pass --isbn.")

    pdfs = discover_pdfs(args.pdfs, args.pdf_dir)
    all_chunks: list[Chunk] = []
    for pdf in pdfs:
        all_chunks.extend(
            extract_chunks(pdf, chunk_words_count=args.chunk_words, overlap=args.chunk_overlap)
        )

    if not all_chunks:
        raise ValueError("No text chunks were extracted from the provided PDFs.")

    print(f"Loading embedding model: {args.model}")
    model = SentenceTransformer(args.model)

    client = MongoClient(args.mongodb_uri)
    collection = client[args.db][args.collection]
    collection.create_index([("textbook_id", 1), ("isbn", 1)])
    collection.create_index([("source_file", 1), ("page", 1)])

    if args.replace_textbook:
        delete_result = collection.delete_many({"isbn": args.isbn})
        print(f"Deleted {delete_result.deleted_count} existing chunks for ISBN {args.isbn}.")

    uploaded = 0
    for chunk_batch in tqdm(list(batched(all_chunks, args.batch_size)), desc="Embedding and uploading"):
        embeddings = embed_documents(model, [chunk.text for chunk in chunk_batch], args.embedding_dim)
        operations = build_operations(
            chunks=chunk_batch,
            embeddings=embeddings,
            textbook_id=args.textbook_id,
            isbn=args.isbn,
            model_name=args.model,
            embedding_dim=args.embedding_dim,
            chunk_words_count=args.chunk_words,
            chunk_overlap=args.chunk_overlap,
        )
        if operations:
            collection.bulk_write(operations, ordered=False)
            uploaded += len(operations)

    print(
        f"Uploaded {uploaded} chunks to {args.db}.{args.collection} "
        f"for ISBN {args.isbn} and textbook_id={args.textbook_id} with {args.embedding_dim}d embeddings."
    )


if __name__ == "__main__":
    main()
