# Error Handling and User Feedback

This document describes the error handling and user feedback infrastructure implemented for the Meeting Recorder app.

## Error Handling Infrastructure

### Error Types

All error types are defined in `Errors.swift` and conform to `LocalizedError` for user-friendly error messages:

- **RecordingError**: Errors related to audio recording operations
  - `microphonePermissionDenied`
  - `audioSessionConfigurationFailed`
  - `recordingInProgress`
  - `noActiveRecording`
  - `diskSpaceInsufficient`
  - `audioEngineFailure`

- **TranscriptionError**: Errors related to speech-to-text operations
  - `speechRecognitionUnavailable`
  - `speechRecognitionPermissionDenied`
  - `recognitionFailed(underlying:)`
  - `audioFormatUnsupported`
  - `recognitionLimitExceeded`

- **StorageError**: Errors related to local storage operations
  - `recordingNotFound`
  - `fileOperationFailed(underlying:)`
  - `corruptedData`
  - `quotaExceeded`
  - `saveContextFailed(underlying:)`
  - `encodingFailed(underlying:)`
  - `decodingFailed(underlying:)`
  - `missingRequiredFields`

- **SyncError**: Errors related to iCloud synchronization
  - `iCloudUnavailable`
  - `networkUnavailable`
  - `authenticationFailed`
  - `conflictDetected`
  - `uploadFailed(underlying:)`

- **SpeakerError**: Errors related to speaker detection
  - `detectionFailed`
  - `profileNotFound`
  - `invalidSpeakerID`

### Error Logging

The `ErrorLogger` utility provides centralized error logging using OSLog:

```swift
ErrorLogger.log(error, context: "MyView.operation")
```

### Error Alert Modifier

The `errorAlert` view modifier provides consistent error presentation:

```swift
.errorAlert($error)
```

## User Feedback Mechanisms

### Toast Notifications

Toast notifications provide non-intrusive feedback for operations:

```swift
@StateObject private var toastManager = ToastManager()

// Show different types of toasts
toastManager.success("Recording saved")
toastManager.info("Syncing to iCloud")
toastManager.warning("Low storage space")
toastManager.error("Failed to save recording")

// Apply to view
.toast(toastManager)
```

### Loading Indicators

Loading overlays show progress for async operations:

```swift
.loading(isLoading, message: "Loading recordings...")
```

### Progress Views

Progress overlays display detailed progress for long-running tasks:

```swift
.progressOverlay(
    isShowing: isExporting,
    title: "Exporting",
    progress: exportProgress,
    message: "Preparing your recording..."
)
```

### Haptic Feedback

Haptic feedback provides tactile responses for key interactions:

```swift
HapticFeedback.recordingStart()  // Heavy impact
HapticFeedback.recordingStop()   // Medium impact
HapticFeedback.recordingPause()  // Light impact
HapticFeedback.success()         // Success notification
HapticFeedback.error()           // Error notification
HapticFeedback.buttonTap()       // Light impact
```

## Best Practices

1. **Always log errors**: Use `ErrorLogger.log()` when catching errors
2. **Provide context**: Include context string when logging errors
3. **Use appropriate feedback**: Match feedback type to operation importance
4. **Combine mechanisms**: Use multiple feedback types for critical operations
5. **Handle errors gracefully**: Always provide user-friendly error messages

## Example Usage

See `UserFeedbackExamples.swift` for comprehensive examples of how to use these utilities in your views and view models.

## Files

- `Errors.swift` - Error type definitions and ErrorLogger
- `ErrorAlert.swift` - Error alert view modifier
- `ToastView.swift` - Toast notification system
- `LoadingView.swift` - Loading indicator overlay
- `ProgressView+Extensions.swift` - Progress overlay for long tasks
- `HapticFeedback.swift` - Haptic feedback utility
- `UserFeedbackExamples.swift` - Usage examples
