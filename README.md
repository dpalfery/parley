# Meeting Recorder MVP

An iOS application for recording meetings with real-time transcription, speaker identification, and cloud storage integration.

## Project Structure

```
MeetingRecorder/
├── MeetingRecorderApp.swift       # App entry point
├── ContentView.swift              # Main content view
├── Info.plist                     # App configuration and permissions
├── MeetingRecorder.entitlements   # iCloud and capabilities configuration
├── Models/                        # Data models
│   └── Recording.swift            # Core recording model
├── Services/                      # Service protocols and implementations
│   ├── RecordingServiceProtocol.swift
│   ├── TranscriptionServiceProtocol.swift
│   ├── SpeakerServiceProtocol.swift
│   ├── StorageManagerProtocol.swift
│   └── CloudSyncServiceProtocol.swift
├── Views/                         # SwiftUI views
├── ViewModels/                    # View models
├── Utilities/                     # Utility classes and helpers
│   └── Errors.swift               # Error definitions
└── Resources/                     # Assets and resources
```

## Requirements

- iOS 16.0+
- Xcode 14.0+
- Swift 5.7+

## Capabilities

The project is configured with the following capabilities:

- **Microphone Access**: Required for audio recording
- **Speech Recognition**: Required for real-time transcription
- **iCloud**: For cloud storage and synchronization
- **Background Modes (Audio)**: For continuous recording when app is backgrounded

## Permissions

The app requires the following permissions (configured in Info.plist):

- `NSMicrophoneUsageDescription`: Access to microphone for recording
- `NSSpeechRecognitionUsageDescription`: Access to speech recognition for transcription

## Getting Started

1. Open `MeetingRecorder.xcodeproj` in Xcode
2. Configure your development team in project settings
3. Update the bundle identifier if needed
4. Build and run on a physical device (required for microphone and speech recognition)

## Architecture

The app follows a clean architecture pattern with:

- **Protocol-based services**: All services are defined as protocols for testability
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for state management
- **Core Data**: Local persistence
- **CloudKit**: Cloud synchronization

## Next Steps

Refer to `.kiro/specs/meeting-recorder-mvp/tasks.md` for the implementation plan.
