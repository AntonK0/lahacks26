# FastAPI Retrieval Backend

Self-contained deployable backend for ISBN-scoped MongoDB Atlas Vector Search.

The iOS app sends an already-generated 768-dimensional query vector plus the scanned ISBN. This service validates the request, runs `$vectorSearch` with `filter: { isbn }`, and returns only chunks for that textbook.

## Files

```text
retrieve_backend/
  main.py
  config.py
  db.py
  models.py
  requirements.txt
  .env.example
```

## Local Setup

```powershell
cd backend\retrieve_backend
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
PORT=8000
ALLOWED_ORIGINS=*
```

If your MongoDB password has special characters, URL-encode it. For example, `@` becomes `%40`, `#` becomes `%23`, `&` becomes `%26`, and `+` becomes `%2B`.

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

## Retrieve Context

```powershell
$body = @{
  isbn = "9780000000000"
  queryVector = @(0.0) * 768
  limit = 5
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:8000/retrieve-context `
  -ContentType "application/json" `
  -Body $body
```

The example vector only checks request shape. Real retrieval needs a query vector generated with the same EmbeddingGemma settings as ingestion.

## Deploy

Deploy this `retrieve_backend/` folder as the app root. Use:

```text
uvicorn main:app --host 0.0.0.0 --port $PORT
```

Set environment variables in the host dashboard. Do not deploy a real `.env` file.
