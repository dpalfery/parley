# Speaker Identification Design Specification

## 1. Objective
To implement a robust, real-time speaker diarization system for the iOS meeting recorder application.

### key Requirements
*   **Accuracy:** > 90% for speaker identification.
*   **Capacity:** Support for differentiating 10+ distinct speakers.
*   **Latency:** Low latency (< 500ms) for real-time UI updates.
*   **Processing:** Completely on-device (offline capability).
*   **Output:** Structured data linking timestamps to speaker labels (e.g., "Speaker 1", "Speaker 2").

## 2. Feasibility Analysis

### Native iOS Capabilities (`SFSpeechRecognizer` / `SoundAnalysis`)
*   **Status:** ❌ **Insufficient.**
*   **Reasoning:** Native frameworks do not provide speaker diarization (segmentation by identity) APIs. They are limited to speech-to-text and general sound classification. Building this from scratch using raw audio buffers and custom heuristics (like energy/pauses) is unreliable for multi-speaker environments.

### Open Source Solutions
*   **Status:** ✅ **Feasible.**
*   **Recommended Path:** Integrate specialized machine learning models converted for mobile execution.
*   **Top Candidates:**
    *   **Sherpa-ONNX:** A cross-platform speech processing framework that supports speaker diarization using ONNX Runtime. It is highly optimized for mobile and supports VAD (Voice Activity Detection) and embedding extraction out of the box.
    *   **FluidAudio (Core ML):** A Swift wrapper around similar models converted to Core ML.

## 3. Recommended Solution: Sherpa-ONNX

We will proceed with **Sherpa-ONNX** due to its robust support for real-time streaming diarization and mature ecosystem for mobile deployment.

### Core Technologies
*   **Inference Engine:** `sherpa-onnx` (via Swift Package Manager).
*   **VAD Model:** `silero-vad` (for discarding silence and reducing compute).
*   **Embedding Model:** `3d-speaker` or `wespeaker` (converted to ONNX for extracting voice fingerprints).
*   **Clustering:** Online clustering algorithm (e.g., Agglomerative Clustering with cosine similarity thresholds).

## 4. System Architecture

The `DiarizationService` will operate in parallel with the existing `TranscriptionService`, both consuming the same audio buffer stream.

```mermaid
graph TD
    Input[Microphone Input (AVAudioEngine)] -->|Audio Buffer| RingBuffer(Ring Buffer)
    RingBuffer -->|Resampled 16kHz Mono| VAD{VAD Check}
    VAD -->|Silence| Skip[Discard Frame]
    VAD -->|Speech Detected| EmbedModel[Speaker Embedding Model (ONNX)]
    EmbedModel -->|Embedding Vector (256/512 dim)| Clustering[Online Clustering Engine]
    Clustering -->|Match Found| Assign[Assign Existing Speaker ID]
    Clustering -->|No Match| Create[Create New Speaker ID]
    Assign & Create -->|Speaker Segment| Alignment[Alignment Service]
    Alignment -->|Merge| UI[Update Transcript UI]
```

## 5. Detailed Workflow

### A. Audio Capture & Preprocessing
*   **Source:** Subscribe to `RecordingService.audioBufferPublisher`.
*   **Preprocessing:** Convert the incoming audio buffer (likely 44.1kHz/48kHz) to **16kHz Mono**, which is the standard input format for diarization models. Using a lightweight ring buffer helps smooth out jitter.

### B. Voice Activity Detection (VAD)
*   **Model:** Silero VAD (provided by Sherpa-ONNX).
*   **Function:** Analyze audio frames (e.g., 30-50ms chunks). If probability of speech < threshold (e.g., 0.5), skip processing.
*   **Benefit:** Crucial for meeting the **< 500ms latency** requirement by preventing the heavy embedding model from running on silence.

### C. Embedding Extraction
*   **Model:** `wespeaker-resnet34` or similar ONNX model.
*   **Input:** Active speech segments.
*   **Output:** A high-dimensional vector (embedding) representing the unique acoustic features of the voice.

### D. Online Clustering (The "Brain")
To support **10+ speakers** dynamically:
1.  **Centroids:** Maintain a list of "Speaker Centroids" (average embedding vector for each identified speaker).
2.  **Comparison:** For every new embedding, calculate **Cosine Similarity** against all known centroids.
3.  **Decision Logic:**
    *   **If Similarity > Threshold (e.g., 0.75):** Assign audio to that Speaker ID. Update that speaker's centroid with the new data (moving average).
    *   **If Similarity < Threshold:** Register a new Speaker ID (e.g., "Speaker N+1") and initialize a new centroid.

### E. Transcript Alignment
*   **Input 1:** Text Segments from `TranscriptionService` (Text + Timestamp).
*   **Input 2:** Speaker Segments from `DiarizationService` (Speaker ID + Timestamp).
*   **Logic:** In the `RecordingViewModel` (or a dedicated `TranscriptMerger`), map the timestamp of the text segment to the dominant speaker ID active during that time window.

## 6. Implementation Steps

1.  **Dependencies:**
    *   Add `sherpa-onnx` to the project using Swift Package Manager (SPM).
2.  **Model Management:**
    *   Download the required `.onnx` models (VAD, Embedding, Segmentation).
    *   Add them to the Xcode project bundle.
3.  **Service Creation:**
    *   Implement `DiarizationService` conforming to a protocol.
    *   Initialize the Sherpa-ONNX engine with the model paths.
4.  **Integration:**
    *   Wire up `RecordingService` -> `DiarizationService`.
    *   Update `TranscriptionService` (or ViewModel) to consume speaker labels.

## 7. Requirements Verification

| Requirement | Feasibility | Notes |
| :--- | :--- | :--- |
| **Real-time Processing** | ✅ High | ONNX Runtime is highly optimized for mobile CPUs/NPUs. |
| **Accuracy > 90%** | ⚠️ Conditional | Achievable in good acoustic conditions. Heavy noise or over-talk will degrade this. |
| **10+ Speakers** | ✅ Supported | Online clustering scales dynamically with the number of unique embeddings found. |
| **Latency < 500ms** | ✅ Feasible | VAD + Efficient Embedding models keep inference time low. |
