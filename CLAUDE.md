# Hackathon Project Blueprint: Edge-Compute AR Tutor
**Repository / Working Document**

## 1. System Architecture Overview
This document outlines the implementation strategy for an edge-compute augmented reality learning platform. The iOS device still owns the AR experience and local LLM response generation, while the FastAPI backend owns query embedding, credential isolation, and ISBN-scoped factual retrieval.

### Primary Tech Stack
* **Client & Interactivity:** iOS Native (SwiftUI, ARKit Plane Detection, `AVFoundation` Barcode Scanning, `SFSpeechRecognizer`)
* **On-Device AI (Zetic ML):** `gemma-4-e4b` (Text Generation)
* **Backend Query Embedding:** `google/embeddinggemma-300m`
* **Routing Memory (Ultra-Fast):** Redis (e.g., Upstash Serverless)
* **Asset Hosting:** Cloudinary
* **Retrieval API:** FastAPI Python backend (`/retrieve-context`)
* **Knowledge Database:** MongoDB Atlas (Vector Search, shared `textbook_chunks` collection)
* **Voice Synthesis:** ElevenLabs (WebSocket API)

---

## 2. Component Implementation Details

### A. The Initialization Phase (Data Routing & Asset Loading)
The app dynamically loads the environment based on the physical book and secures local ML assets.

**Key Implementation Steps:**
1.  **Barcode Scan:** Use `AVFoundation` (`AVCaptureMetadataOutput`) to scan the `ean13` barcode on the back of the textbook to extract the ISBN.
2.  **Redis Lookup:** The iOS app sends a GET request to the Redis instance with the ISBN as the key.
    * *Redis Payload Example:* `{"asset_url": "https://res.cloudinary.com/.../avatar.usdz"}`
3.  **Asset Download:** The app downloads the `.usdz` file from Cloudinary and stores it in the local cache.

### B. The Anchoring Phase (ARKit)
Avoid glossy page reflection issues by using horizontal plane detection.

**Key Implementation Steps:**
1.  **Plane Detection:** Configure `ARWorldTrackingConfiguration` with `planeDetection = [.horizontal]`.
2.  **Placement:** Prompt the user to "Look at the table." When ARKit detects a flat surface, allow the user to tap the screen to anchor the downloaded Cloudinary `.usdz` model onto the physical desk next to the book.

### C. The Heavy Edge Client & RAG Loop
The iPad handles ALL intelligence locally using modern asynchronous streams. The cloud is strictly used as a factual lookup table.

**Key Implementation Steps:**
1.  **Native Speech Capture:** Transcribe the user's question locally using `SFSpeechRecognizer`.
2.  **Server Query Embedding:** The iOS app sends the transcribed text message and scanned ISBN to the FastAPI backend. The backend embeds the message with `google/embeddinggemma-300m` using the query embedding path.
3.  **ISBN-Scoped Retrieval:** The backend executes MongoDB Atlas `$vectorSearch` with `filter: { isbn: scannedISBN }` and returns only matching paragraphs from that textbook.
4.  **Edge Inference:** The app formats the prompt (`[Context] + [Query]`) and passes it to the local Gemma 4 model via Zetic to generate the response tokens.
5.  **Voice Synthesis:** As tokens are generated natively, stream them over a WebSocket to ElevenLabs. Feed the returning audio buffer to `AVAudioEngine` for zero-latency playback.

### D. The Retrieval Backend (FastAPI + MongoDB Atlas)
The backend is a thin security boundary between the iOS app and Atlas.

**Implementation Steps:**
1.  **Credential Isolation:** Store `MONGODB_URI` only in the FastAPI backend environment, never in the iOS app.
2.  **Request Validation:** Require `isbn` and a non-empty text `message` for every `/retrieve-context` request.
3.  **Query Embedding:** Embed the message with `google/embeddinggemma-300m`, normalize it to the same 768-dimensional vector space as document ingestion, and use it as the Atlas query vector.
4.  **Scoped Vector Search:** Query the shared `textbook_chunks` collection with an ISBN filter so one textbook's chunks cannot contaminate another textbook's RAG context.
5.  **Compact Response:** Return only the fields needed by the client: `text`, `isbn`, `source_file`, `page`, `chunk_index`, and vector score.

### E. The Knowledge Pipeline (MongoDB Atlas)
The offline ingestion must perfectly match the on-device math and preserve ISBN as the RAG boundary.

**Implementation Steps:**
1.  **Offline Ingestion:** Use `ingestion/ingest.py` with the `sentence-transformers` library to pull `google/embeddinggemma-300m` from Hugging Face. Parse textbook PDFs, embed chunks through this model, and upload text/vectors to MongoDB Atlas.
2.  **ISBN Separation:** Store all textbooks in one shared collection (`lahacks.textbook_chunks`), but require every chunk to include `isbn`. Re-ingestion and retrieval are scoped by ISBN.
3.  **Indexing:** Establish a 768-dimensional Atlas Vector Search index on `embedding` with `isbn` and `source_file` as filter fields. Because both document ingestion and backend query embedding use the exact same `EmbeddingGemma` weights and normalization, the vectors will map consistently.

---

## 3. Demo "Golden Path" Strategy

1.  **The Init:** Hand the judge the iPad. Ask them to scan the barcode on the back of the textbook.
2.  **The Anchor:** Tell the judge to look at the table next to the book and tap the screen. The avatar appears.
3.  **The Interaction:** The judge asks a question about the material.
4.  **The Edge-Compute Pitch:** While the system runs, state: *"Your voice was transcribed on-device. Our FastAPI backend embeds the query with `EmbeddingGemma` and performs an ISBN-filtered MongoDB Atlas Vector Search for textbook context. The actual AI generating the response is Gemma 4, running locally on this iPad's neural engine via Zetic, streaming out to ElevenLabs for the voice."*
5.  **The Payoff:** The avatar responds seamlessly, proving you have built a scalable, privacy-first, hallucination-free pipeline that owns its entire AI stack.
