# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Parley is an iOS meeting recorder app with real-time transcription, speaker identification, and cloud synchronization. The app follows a clean architecture pattern with protocol-based services and SwiftUI for the UI.

## Build and Test Commands

This is an iOS Swift/SwiftUI application using Xcode:

### Building
```bash
# Open project in Xcode
open Parley.xcodeproj

# Build from command line
xcodebuild -scheme Parley -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for device
xcodebuild -scheme Parley -destination 'generic/platform=iOS'
```

### Testing
```bash
# Run all tests
xcodebuild test -scheme Parley -destination 'platform=iOS Simulator,name=iPhone 15'

# Run unit tests only
xcodebuild test -scheme Parley -only-testing:ParleyTests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests only
xcodebuild test -scheme Parley -only-testing:ParleyUITests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme Parley -only-testing:ParleyTests/RecordingServiceTests -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture

### Service Layer (Protocol-Based)
The app uses a protocol-driven architecture where all core services are defined as protocols and implemented separately:

- **RecordingService**: Audio recording with AVFoundation
- **TranscriptionService**: Speech-to-text using Speech framework and Whisper API fallback
- **SpeakerService**: Speaker diarization and voice profile management
- **StorageManager**: Local persistence with Core Data
- **CloudSyncService**: iCloud synchronization using CloudKit
- **ExportService**: Multiple export formats (text, markdown, PDF, audio)

### Data Flow
1. **Recording**: `RecordingService` → `TranscriptionService` → `SpeakerService`
2. **Storage**: Services → `StorageManager` (Core Data) → `CloudSyncService` (iCloud)
3. **UI**: `ViewModels` coordinate between services and SwiftUI views

### Key Models
- **Recording**: Core data model with audio file, transcript, speakers, metadata
- **TranscriptSegment**: Time-stamped transcript chunks with speaker attribution
- **SpeakerProfile**: Voice profiles for automatic speaker recognition
- **Note**: Time-stamped notes linked to recordings

### Error Handling
Centralized error handling with:
- Custom error types for each service (`RecordingError`, `TranscriptionError`, etc.)
- `ErrorLogger` for centralized logging using OSLog
- `errorAlert` view modifier for consistent UI error presentation
- Toast notifications for non-critical feedback

### Permissions Required
- Microphone access (`NSMicrophoneUsageDescription`)
- Speech recognition (`NSSpeechRecognitionUsageDescription`)
- iCloud entitlements for sync

## File Organization

- `Models/`: Data models and Core Data entities
- `Services/`: Protocol definitions and service implementations
- `Views/`: SwiftUI views organized by feature
- `ViewModels/`: View models following MVVM pattern
- `Utilities/`: Error handling, UI helpers, Core Data utilities
- `Resources/`: Core Data model files and assets

## Development Notes

- Tests are organized into unit tests (`ParleyTests/Services/`), integration tests (`ParleyTests/Integration/`), and UI tests (`ParleyUITests/`)
- The app supports offline recording with native transcription and cloud sync when connectivity returns
- Speaker profiles use voice biometrics stored locally with optional encrypted cloud backup
- Export functionality supports multiple formats with proper timestamp and speaker attribution