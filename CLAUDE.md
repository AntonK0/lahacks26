# Hackathon Project Blueprint: Edge-Compute AR Tutor
**Repository / Working Document**

## 1. System Architecture Overview
This document outlines the implementation strategy for a fully decentralized edge-compute augmented reality learning platform. By hosting the embedding model, the LLM, and modern continuous-transcription models directly on the iOS device, we bypass cloud inference latency, ensure absolute data privacy, and maintain a lightweight, serverless cloud footprint.

### Primary Tech Stack
* **Client & Interactivity:** iOS Native (SwiftUI, ARKit Plane Detection, `AVFoundation` Barcode Scanning)
* **Native Audio Processing:** `SpeechAnalyzer` & `AssetInventory` (Continuous Async Transcription)
* **On-Device AI (Zetic ML):** * `gemma-4-e4b` (Text Generation)
    * `EmbeddingGemma` (300M) (Query Vectorization)
* **Routing Memory (Ultra-Fast):** Redis (e.g., Upstash Serverless)
* **Asset Hosting:** Cloudinary
* **Retrieval API:** MongoDB Atlas App Services (Serverless HTTPS Endpoint)
* **Knowledge Database:** MongoDB Atlas (Vector Search)
* **Voice Synthesis:** ElevenLabs (WebSocket API)

---

## 2. Component Implementation Details

### A. The Initialization Phase (Data Routing & Asset Loading)
The app dynamically loads the environment based on the physical book and secures local ML assets.

**Key Implementation Steps:**
1.  **Speech Asset Reservation:** Upon app launch, use `AssetInventory` to ensure the local English transcription model is loaded into the iPad's memory, guaranteeing 100% offline speech recognition without the legacy 60-second timeout.
2.  **Barcode Scan:** Use `AVFoundation` (`AVCaptureMetadataOutput`) to scan the `ean13` barcode on the back of the textbook to extract the ISBN.
3.  **Redis Lookup:** The iOS app sends a GET request to the Redis instance with the ISBN as the key.
    * *Redis Payload Example:* `{"asset_url": "https://res.cloudinary.com/.../avatar.usdz", "atlas_collection": "bio_textbook_v1"}`
4.  **Asset Download:** The app downloads the `.usdz` file from Cloudinary and stores it in the local cache.

### B. The Anchoring Phase (ARKit)
Avoid glossy page reflection issues by using horizontal plane detection.

**Key Implementation Steps:**
1.  **Plane Detection:** Configure `ARWorldTrackingConfiguration` with `planeDetection = [.horizontal]`.
2.  **Placement:** Prompt the user to "Look at the table." When ARKit detects a flat surface, allow the user to tap the screen to anchor the downloaded Cloudinary `.usdz` model onto the physical desk next to the book.

### C. The Heavy Edge Client & RAG Loop
The iPad handles ALL intelligence locally using modern asynchronous streams. The cloud is strictly used as a factual lookup table.

**Key Implementation Steps:**
1.  **Continuous Native Speech:** Feed `AnalyzerInput` buffers from the microphone into `SpeechAnalyzer`. Use Swift's `async`/`await` to consume the transcription stream on a background thread without freezing the UI.
2.  **Local Vectorization:** The iOS app passes the transcribed text query to the quantized `EmbeddingGemma` model running natively via Zetic. This generates the mathematical vector on-device.
3.  **Serverless Retrieval:** The app sends the *raw vector* and the `atlas_collection` string (from Redis) to a MongoDB Atlas App Services endpoint. The serverless function executes a `$vectorSearch` and returns the matching paragraphs.
4.  **Edge Inference:** The app formats the prompt (`[Context] + [Query]`) and passes it to the local Gemma 4 model via Zetic to generate the response tokens.
5.  **Voice Synthesis:** As tokens are generated natively, stream them over a WebSocket to ElevenLabs. Feed the returning audio buffer to `AVAudioEngine` for zero-latency playback.

### D. The Knowledge Pipeline (MongoDB Atlas)
The offline ingestion must perfectly match the on-device math.

**Implementation Steps:**
1.  **Offline Ingestion:** Use a Python script with the `sentence-transformers` library to pull `google/embeddinggemma-300m` from Hugging Face. Parse the textbook PDFs, embed the chunks through this model, and upload the text and vectors to Atlas.
2.  **Indexing:** Establish a `knnVector` index to enable `$vectorSearch`. Because both the iPad and the Python script use the exact same `EmbeddingGemma` weights, the vectors will map perfectly.

---

## 3. Demo "Golden Path" Strategy

1.  **The Init:** Hand the judge the iPad. Ask them to scan the barcode on the back of the textbook.
2.  **The Anchor:** Tell the judge to look at the table next to the book and tap the screen. The avatar appears.
3.  **The Interaction:** Tell the judge they can talk naturally without rushing, because the modern `SpeechAnalyzer` pipeline doesn't have a 60-second limit. 
4.  **The Edge-Compute Pitch:** While the system runs, state: *"Your voice was transcribed via Apple's modern `SpeechAnalyzer`, which we forced to run 100% offline via `AssetInventory`. We generated the RAG vector locally on the iPad using `EmbeddingGemma`, and queried a serverless MongoDB endpoint for the textbook context. The AI generating the response is Gemma 4, running entirely offline on this iPad via Zetic, streaming out to ElevenLabs for the voice."*
5.  **The Payoff:** The avatar responds seamlessly, proving you have built a scalable, privacy-first, hallucination-free pipeline that leverages the bleeding edge of Swift concurrency and on-device AI.
