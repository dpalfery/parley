# Parley (Meeting Recorder MVP)

Parley is an iOS application designed to record meetings with real-time transcription, speaker identification, and cloud synchronization. It leverages native iOS frameworks to provide a privacy-focused and efficient recording experience.

## Project Overview

*   **Type:** iOS Application
*   **Language:** Swift 5.7+
*   **UI Framework:** SwiftUI
*   **Architecture:** MVVM (Model-View-ViewModel) with Protocol-Based Services
*   **Persistence:** Core Data (Metadata) + File System (Audio/Transcripts) + CloudKit (Sync)
*   **Platform:** iOS 16.0+

## Key Features

1.  **Recording:** High-quality audio recording using `AVFoundation`.
2.  **Transcription:** Real-time speech-to-text using the native `Speech` framework (`SFSpeechRecognizer`).
3.  **Speaker Diarization:** Identifies and labels different speakers (Speaker 1, Speaker 2, etc.).
4.  **Storage & Sync:** Local storage with automatic background synchronization to iCloud Drive.
5.  **Export:** Supports exporting transcripts to Text, Markdown, and PDF, as well as the raw audio.
6.  **Playback:** Synchronized audio playback with transcript highlighting.

## Directory Structure

*   `Parley/` - Main application source code.
    *   `MeetingRecorderApp.swift` - App entry point.
    *   `Models/` - Core data entities (`Recording`, `TranscriptSegment`, `SpeakerProfile`).
    *   `Services/` - Business logic defined by protocols (`RecordingService`, `TranscriptionService`, etc.).
    *   `ViewModels/` - View logic and state management (`RecordingViewModel`, `RecordingListViewModel`).
    *   `Views/` - SwiftUI views (`RecordingView`, `RecordingListView`).
    *   `Utilities/` - Helpers, extensions, and error handling.
    *   `Resources/` - Assets and Core Data model definition.
*   `ParleyTests/` - Unit and integration tests.
*   `ParleyUITests/` - UI automation tests.
*   `.kiro/specs/` - Requirements and design specifications.

## Development

### Building and Running

This project uses standard Xcode tooling.

**Build for Simulator:**
```bash
xcodebuild -scheme Parley -destination 'platform=iOS Simulator,name=iPhone 15' build
```

**Run Tests:**
```bash
# Run all tests
xcodebuild test -scheme Parley -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test suite
xcodebuild test -scheme Parley -only-testing:ParleyTests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### coding Conventions

*   **Architecture:** Strictly follow the MVVM pattern. Logic should reside in ViewModels or Services, not Views.
*   **Services:** All services must act through protocols to facilitate dependency injection and testing.
*   **Concurrency:** Use Swift Concurrency (`async`/`await`) for asynchronous operations.
*   **Error Handling:** Use the centralized `ErrorAlert` and `Errors.swift` definitions.
*   **Style:** Follow standard Swift API Design Guidelines.

## Key Models

*   **Recording:** The central entity containing metadata, audio path, and transcript segments.
*   **TranscriptSegment:** A chunk of transcribed text with timestamp, duration, and speaker ID.
*   **SpeakerProfile:** Represents a distinct speaker with a name and voice signature.

## Recent Changes & Roadmap

Refer to `.kiro/specs/meeting-recorder-mvp/tasks.md` for the implementation status and upcoming tasks. The project is currently in the MVP phase, focusing on core stability and basic feature completeness.
