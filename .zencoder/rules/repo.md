---
description: Repository Information Overview
alwaysApply: true
---

# Parley iOS Meeting Recorder

## Summary

Parley is an iOS meeting recorder application built with Swift and SwiftUI. It provides real-time transcription, speaker identification, and cloud synchronization capabilities. The app follows a clean architecture pattern with protocol-based services for testability and maintainability.

## Structure

```
Parley/
├── Models/                    # Data models and error types
├── Services/                  # Protocol definitions and service implementations
├── Views/                     # SwiftUI views organized by feature
├── ViewModels/                # MVVM view models
├── Utilities/                 # Error handling, UI helpers, Core Data utilities
├── Resources/                 # Core Data model files and assets
├── Media.xcassets/            # Image and icon assets
├── Info.plist                 # App configuration and permissions
├── Parley.entitlements        # iCloud and capabilities configuration
├── ParleyApp.swift            # App entry point
└── ContentView.swift          # Root content view

ParleyTests/
├── Services/                  # Unit tests for services
├── Integration/               # End-to-end integration tests
└── ViewModels/                # View model tests

ParleyUITests/                 # UI automation tests
```

## Language & Runtime

**Language**: Swift  
**Swift Version**: 5.0  
**iOS Deployment Target**: iOS 17.0 (main app), iOS 26.x for tests  
**Build System**: Xcode (Xcode 14.0+)  
**Package Manager**: None (native Xcode dependencies only)

## Main Frameworks

**UI Framework**: SwiftUI  
**Reactive Programming**: Combine  
**Local Storage**: Core Data  
**Cloud Sync**: CloudKit  
**Audio**: AVFoundation  
**Speech Recognition**: Speech Framework

## Services Architecture

**Protocol-Based Services**:
- `RecordingService` - Audio recording lifecycle management with AVFoundation
- `TranscriptionService` - Speech-to-text with Speech Framework and Whisper API fallback
- `SpeakerService` - Speaker diarization and voice profile management
- `StorageManager` - Core Data persistence and query operations
- `CloudSyncService` - iCloud synchronization with queue management
- `ExportService` - Multiple export formats (text, markdown, PDF, audio)

## Capabilities & Permissions

**Permissions Required**:
- `NSMicrophoneUsageDescription` - Microphone access for recording
- `NSSpeechRecognitionUsageDescription` - Speech recognition for transcription

**Capabilities**:
- Microphone access
- Speech recognition
- iCloud (CloudKit)
- Background audio execution
- Bluetooth connectivity
- Background fetch

## Data Models

- `Recording` - Core model with audio file, transcript, speakers, metadata
- `TranscriptSegment` - Time-stamped transcript chunks with speaker attribution
- `SpeakerProfile` - Voice profiles for automatic speaker recognition
- Core Data persistence with `Parley.xcdatamodeld`

## Build & Installation

```bash
# Open project in Xcode
open Parley.xcodeproj

# Build for iOS simulator
xcodebuild build -scheme Parley -destination 'platform=iOS Simulator,name=iPhone 14'

# Build for physical device
xcodebuild build -scheme Parley -destination 'generic/platform=iOS'
```

## Testing

**Framework**: XCTest (native iOS testing framework)

**Test Structure**:
- **Unit Tests** (`ParleyTests/Services/`) - Individual service functionality
- **Integration Tests** (`ParleyTests/Integration/`) - End-to-end workflows
- **UI Tests** (`ParleyUITests/`) - User interface interactions

**Test Files**:
- `RecordingServiceTests.swift` - Recording state and audio configuration
- `TranscriptionServiceTests.swift` - Transcript generation and metadata
- `SpeakerServiceTests.swift` - Speaker detection and profiles
- `StorageManagerTests.swift` - Data persistence operations
- `CloudSyncServiceTests.swift` - Sync queue and conflict resolution
- `RecordingFlowIntegrationTests.swift` - Complete recording workflows
- `PlaybackFlowIntegrationTests.swift` - Playback synchronization
- `ExportFlowIntegrationTests.swift` - Export functionality
- `RecordingListUITests.swift`, `RecordingDetailUITests.swift`, `SettingsUITests.swift` - UI interactions

**Run Tests**:

```bash
# All tests
xcodebuild test -scheme Parley -destination 'platform=iOS Simulator,name=iPhone 14'

# Unit tests only
xcodebuild test -scheme Parley -only-testing:ParleyTests

# UI tests only
xcodebuild test -scheme Parley -only-testing:ParleyUITests

# Specific test class
xcodebuild test -scheme Parley -only-testing:ParleyTests/RecordingServiceTests
```

**Test Configuration**:
- In-memory Core Data stores for isolated testing
- Mock service implementations for unit test isolation
- Real-time transcript display and async/await pattern testing

## Entry Points

- `ParleyApp.swift` - Application entry point with App initialization
- `ContentView.swift` - Root content view
- `MainTabView.swift` - Main navigation with tabs
- Feature views: `RecordingView.swift`, `RecordingListView.swift`, `RecordingDetailView.swift`, `SettingsView.swift`

## Configuration Files

- `Parley.xcodeproj/project.pbxproj` - Xcode project configuration
- `Parley/Info.plist` - App metadata, permissions, and UI configuration
- `Parley/Parley.entitlements` - iCloud and app capabilities
- `Parley.xcdatamodeld` - Core Data model definition
