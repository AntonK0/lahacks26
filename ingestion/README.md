# Textbook Ingestion

This is the offline upload path from `CLAUDE.md`: parse textbook PDFs, embed chunks with `google/embeddinggemma-300m`, and write normalized vectors to MongoDB Atlas.

## Setup

```powershell
cd ingestion
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

Edit `.env` with your Atlas connection string and routing metadata. `ISBN` is required because it is the logical boundary for each textbook's RAG corpus. Do not commit `.env`.

EmbeddingGemma is a gated Hugging Face model. Before first ingestion, accept access on the Hugging Face model page, create a read token, and authenticate:

```powershell
hf auth login
hf auth whoami
```

Use `hf`, not the deprecated `huggingface-cli`.

## Upload PDFs

Place PDFs in `ingestion/data/`, then run:

```powershell
python ingest.py --pdf-dir .\data --textbook-id bio_textbook_v1 --isbn 9780000000000 --replace-textbook
```

Or upload specific files:

```powershell
python ingest.py .\data\biology.pdf --textbook-id bio_textbook_v1 --isbn 9780000000000
```

The script is re-runnable. Chunks use stable `_id` values that include the ISBN and are upserted into Atlas. Use `--replace-textbook` when the source PDF or chunking settings changed and you want to remove old chunks for that ISBN first.

## ISBN-Based Separation

All textbooks are stored in one shared collection, usually `textbook_chunks`. They remain logically separate because every chunk stores an `isbn`, and every retrieval query must filter by that same ISBN.

Ingest each textbook with its own ISBN:

```powershell
python ingest.py .\data\biology.pdf --textbook-id bio_textbook_v1 --isbn 9780000000000 --replace-textbook
python ingest.py .\data\chemistry.pdf --textbook-id chem_textbook_v1 --isbn 9781111111111 --replace-textbook
```

Do not create one collection per textbook for the default demo flow. The FastAPI backend rejects unscoped retrieval, so Gemma only receives chunks from the scanned ISBN.

## Test Retrieval

After the Atlas Vector Search index is active, test one ISBN-scoped query:

```powershell
python query_test.py "What is photosynthesis?" --isbn 9780000000000
```

## Important Compatibility Rules

- The Atlas Vector Search index dimension must match `EMBEDDING_DIM`.
- The iOS query embedding path must use the same model, dimensionality, truncation, and normalization.
- The default upload uses 768-dimensional normalized document embeddings and `dotProduct` similarity.
- Missing or wrong ISBN filters are the main contamination risk. Never add a fallback query that searches without ISBN.

## Troubleshooting

- If `SentenceTransformer("google/embeddinggemma-300m")` returns `401 Unauthorized`, confirm that you accepted the gated model license and that `hf auth whoami` shows the correct account.
- If `pymongo` raises `InvalidURI: MongoDB URI options are key=value pairs`, check `MONGODB_URI`. It should look like `mongodb+srv://USER:PASSWORD@cluster.mongodb.net/?retryWrites=true&w=majority`.
- If your MongoDB password contains special characters, URL-encode them. For example, `@` becomes `%40`, `#` becomes `%23`, `&` becomes `%26`, and `+` becomes `%2B`.
- If Atlas connection times out, add your current public IP under Atlas **Network Access**.
- The first model download is large. Later runs should reuse the Hugging Face cache.
