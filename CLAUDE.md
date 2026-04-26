# Hackathon Project Blueprint: Edge-Compute AR Tutor
**Repository / Working Document**

## 1. System Architecture Overview
This document outlines the current architecture for an edge-compute augmented reality learning platform. The iOS device owns barcode scanning, AR rendering, local speech capture, and local LLM response generation, while the FastAPI backend owns textbook upload ingestion, query/document embedding, credential isolation, ISBN-scoped MongoDB Atlas retrieval, and Upstash Redis routing updates.

### Primary Tech Stack
* **Client & Interactivity:** iOS Native (SwiftUI, ARKit Plane Detection, `AVFoundation` Barcode Scanning, `SFSpeechRecognizer`)
* **On-Device AI (Zetic ML):** `gemma-4-e4b` (Text Generation)
* **Backend Embedding Model:** `google/embeddinggemma-300m`
* **Routing Memory:** Upstash Redis REST API
* **Asset Hosting:** Cloudinary
* **Backend API:** FastAPI Python backend (`/upload-textbook`, `/retrieve-context`)
* **Knowledge Database:** MongoDB Atlas (Vector Search, shared `textbook_chunks` collection)
* **Voice Synthesis:** ElevenLabs (WebSocket API)

---

## 2. Component Implementation Details

### A. The Initialization Phase (Data Routing)
The app dynamically loads the avatar asset based on the scanned physical book.

**Key Implementation Steps:**
1.  **Barcode Scan:** Use `AVFoundation` (`AVCaptureMetadataOutput`) to scan the `ean13` barcode on the back of the textbook to extract the ISBN.
2.  **Redis Lookup:** The iOS app calls Upstash Redis REST with `HGETALL/<isbn>`.
3.  **Redis Hash Contract:** Each ISBN key must be a Redis hash with the fields below:
    * `cloudinary_url`: Cloudinary `.usdz` avatar URL.
    * `textbook_id`: currently the same value as the ISBN.
4.  **Asset Download:** The app downloads the `.usdz` file from Cloudinary, extracts the `.usdc` clips, and stores them in the local cache.

### B. The Anchoring Phase (ARKit)
Avoid glossy page reflection issues by using horizontal plane detection.

**Key Implementation Steps:**
1.  **Plane Detection:** Configure `ARWorldTrackingConfiguration` with `planeDetection = [.horizontal]`.
2.  **Placement:** Prompt the user to "Look at the table." When ARKit detects a flat surface, allow the user to tap the screen to anchor the downloaded Cloudinary `.usdz` model onto the physical desk next to the book.

### C. The Heavy Edge Client & RAG Loop
The iPad handles ALL intelligence locally using modern asynchronous streams. The cloud is strictly used as a factual lookup table.

**Key Implementation Steps:**
1.  **Native Speech Capture:** Transcribe the user's question locally using `SFSpeechRecognizer`.
2.  **Server Query Embedding:** The iOS app sends the transcribed text message and scanned ISBN to `POST /retrieve-context`. The backend embeds the message with `google/embeddinggemma-300m` using `encode_query()`.
3.  **ISBN-Scoped Retrieval:** The backend executes MongoDB Atlas `$vectorSearch` with `filter: { isbn: scannedISBN }` and returns only matching paragraphs from that textbook.
4.  **Edge Inference:** The app formats the prompt (`[Context] + [Query]`) and passes it to the local Gemma 4 model via Zetic to generate the response tokens.
5.  **Voice Synthesis:** As tokens are generated natively, stream them over a WebSocket to ElevenLabs. Feed the returning audio buffer to `AVAudioEngine` for zero-latency playback.

### D. The FastAPI Backend
The backend is a thin security boundary between clients and MongoDB Atlas/Upstash. It owns upload ingestion, embedding, retrieval, and server-side credentials.

**Current Backend Files:**
* `backend/main.py`: FastAPI app, routes, CORS, upload validation, retrieval query.
* `backend/config.py`: environment-backed settings.
* `backend/db.py`: cached MongoDB client and collection lookup.
* `backend/embeddings.py`: cached SentenceTransformer, `encode_query()`, `encode_document()`, normalization.
* `backend/textbook_ingestion.py`: PDF extraction, word-window chunking, stable chunk IDs, MongoDB replacement writes.
* `backend/redis_store.py`: Upstash Redis hash writer for iOS avatar lookup.
* `backend/models.py`: Pydantic request/response models.

**Routes:**
1.  **`GET /health`:** Returns `{ "status": "ok" }`.
2.  **`POST /upload-textbook`:** Accepts multipart form data in this order:
    * `isbn`: required ISBN string.
    * `cloudinary_url`: required Cloudinary `.usdz` URL.
    * `file`: uploaded PDF textbook.
3.  **`POST /retrieve-context`:** Accepts JSON with `isbn`, `message`, optional `limit`, and optional `numCandidates`.

**Upload Behavior:**
1.  Validate the ISBN, Cloudinary URL, and PDF upload.
2.  Save the uploaded PDF to a temporary file.
3.  Extract PDF text with `pypdf`.
4.  Chunk text with a word-window chunker (`UPLOAD_CHUNK_WORDS`, `UPLOAD_CHUNK_OVERLAP`).
5.  Embed chunks with `google/embeddinggemma-300m` using `encode_document()`.
6.  Delete existing MongoDB chunks for the ISBN.
7.  Bulk upsert replacement chunks into `lahacks.textbook_chunks`.
8.  Write the Upstash Redis hash:
    * key: `<isbn>`
    * `cloudinary_url`: submitted Cloudinary URL
    * `textbook_id`: `<isbn>`
9.  Return success only if both MongoDB upload and Redis sync succeed.

**Retrieval Behavior:**
1.  Validate `isbn` and non-empty `message`.
2.  Embed the query with `encode_query()`.
3.  Run Atlas `$vectorSearch` on the shared collection with `filter: { isbn: scannedISBN }`.
4.  Return compact chunk fields: `text`, `isbn`, `source_file`, `page`, `chunk_index`, and vector score.

### E. The Knowledge Pipeline (MongoDB Atlas)
The upload and retrieval paths must use matching embedding math and preserve ISBN as the RAG boundary.

**Implementation Steps:**
1.  **Backend Upload Ingestion:** `POST /upload-textbook` is the main upload path for the dashboard/frontend. It embeds and stores PDFs directly from the FastAPI backend.
2.  **Offline Ingestion:** `ingestion/ingest.py` remains available for CLI/offline ingestion and should stay mathematically aligned with backend upload ingestion.
3.  **Embedding Roles:** Document chunks use `encode_document()`. Retrieval queries use `encode_query()`. Both are normalized and truncated to `EMBEDDING_DIM` dimensions.
4.  **ISBN Separation:** Store all textbooks in one shared collection (`lahacks.textbook_chunks`), but require every chunk to include `isbn`. Re-upload and retrieval are scoped by ISBN.
5.  **Indexing:** Establish a 768-dimensional Atlas Vector Search index on `embedding` with `isbn` and `source_file` as filter fields.
6.  **Stored Chunk Fields:** Important fields include `isbn`, `cloudinary_url`, `source_file`, `page`, `chunk_index`, `text`, `embedding`, `model`, `embedding_dim`, `embedding_role`, and `chunker`.

### F. Backend Environment Variables
Required for local backend operation:

```env
MONGODB_URI=mongodb+srv://<user>:<password>@<cluster-url>/?retryWrites=true&w=majority
MONGODB_DB=lahacks
MONGODB_COLLECTION=textbook_chunks
MONGODB_VECTOR_INDEX=textbook_chunks_vector_index
EMBEDDING_MODEL=google/embeddinggemma-300m
EMBEDDING_DIM=768
DOCUMENT_EMBEDDING_BATCH_SIZE=4
UPLOAD_CHUNK_WORDS=320
UPLOAD_CHUNK_OVERLAP=60
UPLOAD_BATCH_SIZE=8
UPSTASH_REDIS_REST_URL=https://<your-redis>.upstash.io
UPSTASH_REDIS_REST_TOKEN=<upstash-rest-token>
HF_TOKEN=<huggingface-read-token>
PORT=8000
ALLOWED_ORIGINS=*
```

Do not ship real `.env` files or embed MongoDB/Upstash/Hugging Face credentials in the iOS app.

---

## 3. Demo "Golden Path" Strategy

1.  **The Init:** Hand the judge the iPad. Ask them to scan the barcode on the back of the textbook.
2.  **The Routing:** The app looks up the scanned ISBN in Upstash Redis, downloads the Cloudinary `.usdz` avatar, and extracts the local animation assets.
3.  **The Anchor:** Tell the judge to look at the table next to the book and tap the screen. The avatar appears.
4.  **The Interaction:** The judge asks a question about the material.
5.  **The Edge-Compute Pitch:** While the system runs, state: *"Your voice was transcribed on-device. Our FastAPI backend embeds the query with `EmbeddingGemma` and performs an ISBN-filtered MongoDB Atlas Vector Search for textbook context. The actual AI generating the response is Gemma 4, running locally on this iPad's neural engine via Zetic, streaming out to ElevenLabs for the voice."*
6.  **The Payoff:** The avatar responds seamlessly, proving you have built a scalable, privacy-first, hallucination-resistant pipeline that owns its AI and retrieval stack.
