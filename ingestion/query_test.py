from __future__ import annotations

import argparse
import math
import os

from dotenv import load_dotenv
from pymongo import MongoClient
from sentence_transformers import SentenceTransformer


DEFAULT_MODEL = "google/embeddinggemma-300m"
DEFAULT_EMBEDDING_DIM = 768


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Embed a test query and run Atlas Vector Search against uploaded textbook chunks."
    )
    parser.add_argument("query", help="Question to search for.")
    parser.add_argument("--textbook-id", default=os.getenv("TEXTBOOK_ID"))
    parser.add_argument("--isbn", default=os.getenv("ISBN") or None, help="Required ISBN routing key.")
    parser.add_argument("--mongodb-uri", default=os.getenv("MONGODB_URI"))
    parser.add_argument("--db", default=os.getenv("MONGODB_DB", "lahacks"))
    parser.add_argument("--collection", default=os.getenv("MONGODB_COLLECTION", "textbook_chunks"))
    parser.add_argument("--index", default=os.getenv("MONGODB_VECTOR_INDEX", "textbook_chunks_vector_index"))
    parser.add_argument("--model", default=os.getenv("EMBEDDING_MODEL", DEFAULT_MODEL))
    parser.add_argument(
        "--embedding-dim",
        type=int,
        default=int(os.getenv("EMBEDDING_DIM", DEFAULT_EMBEDDING_DIM)),
        choices=(128, 256, 512, 768),
    )
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--num-candidates", type=int, default=100)
    return parser.parse_args()


def normalize_vector(vector: list[float]) -> list[float]:
    magnitude = math.sqrt(sum(value * value for value in vector))
    if magnitude == 0:
        raise ValueError("Embedding model returned a zero vector.")
    return [value / magnitude for value in vector]


def truncate_and_normalize(vector: list[float], dimensions: int) -> list[float]:
    if len(vector) < dimensions:
        raise ValueError(f"Embedding has {len(vector)} dimensions, expected at least {dimensions}.")
    return normalize_vector([float(value) for value in vector[:dimensions]])


def embed_query(model: SentenceTransformer, query: str, dimensions: int) -> list[float]:
    embedding = model.encode_query(
        query,
        normalize_embeddings=True,
        convert_to_numpy=True,
        show_progress_bar=False,
    )
    return truncate_and_normalize(embedding.tolist(), dimensions)


def build_filter(isbn: str, textbook_id: str | None) -> dict[str, str]:
    filters = {"isbn": isbn}
    if textbook_id:
        filters["textbook_id"] = textbook_id
    return filters


def main() -> None:
    load_dotenv()
    args = parse_args()

    if not args.mongodb_uri:
        raise ValueError("MONGODB_URI is required. Set it in ingestion/.env or pass --mongodb-uri.")
    if not args.isbn:
        raise ValueError("ISBN is required. Set it in ingestion/.env or pass --isbn.")

    model = SentenceTransformer(args.model)
    query_vector = embed_query(model, args.query, args.embedding_dim)

    vector_search = {
        "index": args.index,
        "path": "embedding",
        "queryVector": query_vector,
        "numCandidates": args.num_candidates,
        "limit": args.limit,
    }

    vector_search["filter"] = build_filter(args.isbn, args.textbook_id)

    client = MongoClient(args.mongodb_uri)
    collection = client[args.db][args.collection]
    results = list(
        collection.aggregate(
            [
                {"$vectorSearch": vector_search},
                {
                    "$project": {
                        "_id": 0,
                        "text": 1,
                        "textbook_id": 1,
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

    if not results:
        print(f"No results found for ISBN {args.isbn}. Check index status, filters, and embedding configuration.")
        return

    print(f"Query scoped to ISBN {args.isbn}.")

    for index, result in enumerate(results, start=1):
        text = result.get("text", "").replace("\n", " ")
        if len(text) > 500:
            text = f"{text[:500]}..."
        print(
            f"\n[{index}] score={result.get('score'):.4f} "
            f"source={result.get('source_file')} page={result.get('page')}"
        )
        print(text)


if __name__ == "__main__":
    main()
