# FastAPI Backend

Self-contained deployable backend for ISBN-scoped query embedding and MongoDB Atlas Vector Search.

The app receives a user message plus the scanned ISBN. It embeds the message with `google/embeddinggemma-300m`, runs `$vectorSearch` with `filter: { isbn }`, and returns only chunks for that textbook.

## Files

```text
backend/
  main.py
  config.py
  db.py
  embeddings.py
  models.py
  redis_store.py
  textbook_ingestion.py
  requirements.txt
  .env.example
```

## Local Setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

Edit `.env` with your Atlas values:

```env
MONGODB_URI=mongodb+srv://<user>:<password>@<cluster-url>/?retryWrites=true&w=majority
MONGODB_DB=lahacks
MONGODB_COLLECTION=textbook_chunks
MONGODB_VECTOR_INDEX=textbook_chunks_vector_index
EMBEDDING_MODEL=google/embeddinggemma-300m
EMBEDDING_DIM=768
UPLOAD_CHUNK_WORDS=320
UPLOAD_CHUNK_OVERLAP=60
UPLOAD_BATCH_SIZE=64
UPSTASH_REDIS_REST_URL=https://<your-redis>.upstash.io
UPSTASH_REDIS_REST_TOKEN=your_upstash_redis_rest_token
HF_TOKEN=your_huggingface_read_token
PORT=8000
ALLOWED_ORIGINS=*
```

If your MongoDB password has special characters, URL-encode it. For example, `@` becomes `%40`, `#` becomes `%23`, `&` becomes `%26`, and `+` becomes `%2B`.

EmbeddingGemma is a gated Hugging Face model. Before deploying, accept model access on Hugging Face and set `HF_TOKEN` to a read token in your host environment.

## Run

From this folder:

```powershell
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Or:

```powershell
python main.py
```

Health check:

```powershell
Invoke-RestMethod http://localhost:8000/health
```

## Upload Textbook

Send multipart form data in this order: `isbn`, `cloudinary_url`, then `file`.

```powershell
$form = @{
  isbn = "9780000000000"
  cloudinary_url = "https://res.cloudinary.com/demo/raw/upload/v1/textbook.pdf"
  file = Get-Item ".\textbook.pdf"
}

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:8000/upload-textbook `
  -Form $form
```

The response includes MongoDB upload counts and the Redis hash written for the iOS app:

```json
{
  "collection": "textbook_chunks",
  "isbn": "9780000000000",
  "cloudinary_url": "https://res.cloudinary.com/demo/raw/upload/v1/textbook.pdf",
  "source_file": "textbook.pdf",
  "deleted_count": 0,
  "uploaded_count": 128,
  "embedding_model": "google/embeddinggemma-300m",
  "embedding_dim": 768,
  "redis": {
    "key": "9780000000000",
    "fields": {
      "cloudinary_url": "https://res.cloudinary.com/demo/raw/upload/v1/textbook.pdf",
      "textbook_id": "9780000000000"
    }
  }
}
```

The backend extracts PDF text, chunks it with the configured word window, embeds chunks with `encode_document()`, deletes existing chunks for that ISBN, and writes the replacement chunks to MongoDB Atlas with the Cloudinary URL stored on each chunk.

After the MongoDB upload succeeds, the backend writes the iOS avatar lookup to Upstash Redis as a hash:

```text
key: <isbn>
cloudinary_url: <cloudinary_url>
textbook_id: <isbn>
```

Verify the Redis record with:

```powershell
curl.exe "$env:UPSTASH_REDIS_REST_URL/HGETALL/9780000000000" `
  -H "Authorization: Bearer $env:UPSTASH_REDIS_REST_TOKEN"
```

The response should include `cloudinary_url`, the uploaded Cloudinary USDZ URL, `textbook_id`, and the ISBN.

## Retrieve Context

```powershell
$body = @{
  isbn = "9780000000000"
  message = "What careers require a bachelor's degree?"
  limit = 5
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:8000/retrieve-context `
  -ContentType "application/json" `
  -Body $body
```

The backend embeds `message` with `encode_query()`. Document ingestion should continue using the same `EMBEDDING_MODEL`, `EMBEDDING_DIM`, normalization, and `encode_document()` path.

## Deploy

Deploy the `backend/` folder as the app root. Use:

```text
uvicorn main:app --host 0.0.0.0 --port $PORT
```

Set environment variables in the host dashboard. Do not deploy a real `.env` file.

The first retrieval request may be slower because the backend lazily downloads and loads EmbeddingGemma.
