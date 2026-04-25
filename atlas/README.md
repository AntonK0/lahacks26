# MongoDB Atlas Retrieval Setup

This folder contains the Atlas-side pieces for the `CLAUDE.md` RAG path. Atlas App Services HTTPS endpoints are deprecated, so use the FastAPI backend in `backend/` for live retrieval. The legacy function remains here as reference-only vector search logic.

1. Run `ingestion/ingest.py` locally to upload textbook chunks.
2. Create the Atlas Vector Search index from `indexes/textbook_chunks_vector_index.json`.
3. Run or deploy the FastAPI backend in `backend/`.
4. Point the iOS app at the backend `/retrieve-context` endpoint and send the user's message plus the scanned ISBN.

## Chunk Document Shape

Each ingested chunk uses this shape:

```json
{
  "_id": "sha256 stable chunk id",
  "isbn": "9780000000000",
  "source_file": "textbook.pdf",
  "page": 12,
  "chunk_index": 3,
  "text": "chunk text",
  "embedding": [0.0123, -0.0456],
  "model": "google/embeddinggemma-300m",
  "embedding_dim": 768,
  "embedding_normalized": true,
  "embedding_role": "document",
  "chunker": {
    "type": "word_window",
    "chunk_words": 320,
    "chunk_overlap": 60
  },
  "created_at": "date",
  "updated_at": "date"
}
```

The app must retrieve by ISBN after barcode routing. ISBN is the required RAG boundary.

## ISBN-Based Logical Separation

All textbooks live in one shared collection, usually `lahacks.textbook_chunks`. Do not create one collection per textbook for the default demo flow.

The separation rule is:

```javascript
filter: {
  isbn: scannedISBN
}
```

The FastAPI backend rejects requests without `isbn`, applies the ISBN as the `$vectorSearch` filter, and returns only chunks from that ISBN. Gemma never sees the whole collection; it only receives the filtered chunks returned by the endpoint.

This prevents cross-textbook contamination as long as every retrieval path goes through the endpoint and never falls back to a global vector search.

## Vector Index

Create an Atlas Vector Search index on the collection used by `MONGODB_COLLECTION`.

- Index name: `textbook_chunks_vector_index`
- Vector path: `embedding`
- Dimensions: `768`
- Similarity: `dotProduct`
- Filter fields: `isbn`, `source_file`

`dotProduct` assumes embeddings are normalized. The ingestion script normalizes document vectors, and the backend normalizes query vectors generated from request messages.

Large numbers of textbooks can share the vector collection. Atlas Vector Search is built for large indexed corpora, and the ISBN filter excludes unrelated textbooks from the results returned to Gemma.

## Atlas Setup Checklist

1. Create or select an Atlas cluster.
2. Create a database user with a strong password.
3. Add your current public IP in **Security > Network Access**.
4. Copy the connection string from **Connect > Drivers** into ingestion/backend `.env` files.
5. In Atlas Vector Search, create the `textbook_chunks_vector_index` index on database `lahacks`, collection `textbook_chunks`.
6. Wait until the vector index is active before running `ingestion/query_test.py`.

## Backend Environment Values

The FastAPI backend expects these environment values:

- `MONGODB_DB`: database name, for example `lahacks`
- `MONGODB_COLLECTION`: default collection, for example `textbook_chunks`
- `MONGODB_VECTOR_INDEX`: default vector index, for example `textbook_chunks_vector_index`
- `EMBEDDING_MODEL`: query embedding model, for example `google/embeddinggemma-300m`
- `EMBEDDING_DIM`: query embedding dimensions, usually `768`
- `HF_TOKEN`: Hugging Face read token for the gated EmbeddingGemma model
- `PORT`: backend port, for example `8000`
- `ALLOWED_ORIGINS`: CORS origins, for example `*` during local testing

The deprecated `functions/retrieveContext.js` file should not be used as a new App Services deployment. It is kept as a reference for the ISBN-scoped `$vectorSearch` aggregation.
