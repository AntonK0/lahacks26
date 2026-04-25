# FastAPI Retrieval Backend

This backend replaces the deprecated Atlas App Services HTTPS endpoint. It receives an on-device query vector from the iOS app, requires an ISBN, runs MongoDB Atlas Vector Search, and returns only chunks for that ISBN.

## Setup

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

Edit `.env` with your Atlas connection string:

```env
MONGODB_URI=mongodb+srv://<user>:<password>@<cluster-url>/?retryWrites=true&w=majority
MONGODB_DB=lahacks
MONGODB_COLLECTION=textbook_chunks
MONGODB_VECTOR_INDEX=textbook_chunks_vector_index
PORT=8000
ALLOWED_ORIGINS=*
```

The MongoDB connection follows the same core pattern as MongoDB's Python starter: create a `pymongo.MongoClient` with your Atlas connection string and use it to access a database and collection.

If your MongoDB password has special characters, URL-encode it in `MONGODB_URI`. For example, `@` becomes `%40`, `#` becomes `%23`, `&` becomes `%26`, and `+` becomes `%2B`.

## Run Locally

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Health check:

```powershell
Invoke-RestMethod http://localhost:8000/health
```

## Retrieve Context

```powershell
$body = @{
  isbn = "9780000000000"
  queryVector = @(0.0) * 768
  textbook_id = "bio_textbook_v1"
  limit = 5
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:8000/retrieve-context `
  -ContentType "application/json" `
  -Body $body
```

The example vector is only useful for checking request validation. Real retrieval needs a query vector generated with the same EmbeddingGemma settings as ingestion.

From a physical iPad, do not use `localhost`. Point `RetrievalClient` at your computer's LAN IP, for example `http://192.168.1.25:8000/retrieve-context`, while the backend is running with `--host 0.0.0.0`.

## Response Shape

```json
{
  "collection": "textbook_chunks",
  "index": "textbook_chunks_vector_index",
  "isbn": "9780000000000",
  "count": 5,
  "chunks": [
    {
      "text": "...",
      "isbn": "9780000000000",
      "textbook_id": "bio_textbook_v1",
      "source_file": "biology.pdf",
      "page": 12,
      "chunk_index": 3,
      "score": 0.91
    }
  ]
}
```

## Atlas Requirements

- The `textbook_chunks` collection must contain documents uploaded by `ingestion/ingest.py`.
- The Atlas Vector Search index must exist and be active.
- The index must use `embedding` as a 768-dimensional vector path.
- The index must include `isbn` as a filter field.

## Troubleshooting

- Verify `MONGODB_URI` is copied from Atlas **Connect > Drivers**.
- Verify the database user and password are correct.
- URL-encode special characters in the password if `pymongo` reports an invalid URI.
- Verify your current IP address is allowed in Atlas Network Access.
- Verify the vector index name matches `MONGODB_VECTOR_INDEX`.
- Verify the app is querying an ISBN that has already been ingested.
- If Atlas returns a vector search error, check that the query vector has 768 numeric values and the index is finished building.
- If the iPad cannot reach the backend, confirm both devices are on the same Wi-Fi and Windows Firewall allows inbound connections to port `8000`.

## Deployment

Deploy this as a normal Python web service on Render, Railway, Fly.io, or another host that can run:

```powershell
uvicorn app.main:app --host 0.0.0.0 --port $env:PORT
```

Set the same environment variables in the host dashboard. Never put `MONGODB_URI` in the iOS app.
