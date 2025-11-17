# Meeting Recorder Tests

This directory contains the test suite for the Meeting Recorder MVP application.

## Test Structure

### Unit Tests (`/Services`)
Unit tests focus on testing individual service components in isolation:

- **RecordingServiceTests.swift** - Tests for audio recording functionality
  - State transitions (idle → recording → paused → stopped)
  - Audio quality configuration
  - Duration tracking
  - Error handling

- **TranscriptionServiceTests.swift** - Tests for transcription functionality
  - Transcript segment creation and metadata
  - Timestamp accuracy
  - Confidence scoring
  - Codable conformance

- **SpeakerServiceTests.swift** - Tests for speaker diarization
  - Speaker detection and segmentation
  - Speaker ID assignment
  - Speaker profile management
  - Codable conformance

- **StorageManagerTests.swift** - Tests for data persistence
  - CRUD operations
  - Search functionality
  - Storage usage tracking
  - Tag filtering

- **CloudSyncServiceTests.swift** - Tests for cloud synchronization
  - Sync queue management
  - Conflict resolution
  - Offline handling
  - Sync status tracking

### Integration Tests (`/Integration`)
Integration tests verify end-to-end workflows across multiple components:

- **RecordingFlowIntegrationTests.swift** - Complete recording workflows
  - Start → transcribe → save → sync flow
  - Pause/resume functionality
  - Multiple recording sessions
  - Cancellation handling

- **PlaybackFlowIntegrationTests.swift** - Playback workflows
  - Load → play → seek flow
  - Transcript synchronization
  - Playback controls
  - Speaker label resolution

- **ExportFlowIntegrationTests.swift** - Export and sharing workflows
  - Plain text export
  - Markdown export
  - Audio file export
  - Share preparation

- **OfflineScenarioTests.swift** - Offline functionality
  - Recording while offline
  - Sync queue accumulation
  - Sync recovery when online
  - Data integrity

### UI Tests (`/MeetingRecorderUITests`)
UI tests verify user interface interactions and flows:

- **RecordingScreenUITests.swift** - Recording screen interactions
  - Record/pause/resume/stop buttons
  - Timer display
  - Audio level visualization
  - Real-time transcript display
  - Notes input

- **RecordingListUITests.swift** - Recording list navigation
  - List display and scrolling
  - Search functionality
  - Filtering options
  - Navigation to detail view

- **RecordingDetailUITests.swift** - Recording detail interactions
  - Playback controls
  - Transcript display and editing
  - Notes management
  - Tag management
  - Export options

- **SettingsUITests.swift** - Settings and storage management
  - Audio quality settings
  - iCloud sync toggle
  - Storage usage display
  - Auto-cleanup configuration

## Running Tests

### Unit Tests
```bash
# Run all unit tests
xcodebuild test -scheme MeetingRecorder -destination 'platform=iOS Simulator,name=iPhone 14'

# Run specific test class
xcodebuild test -scheme MeetingRecorder -only-testing:MeetingRecorderTests/RecordingServiceTests
```

### Integration Tests
```bash
# Run all integration tests
xcodebuild test -scheme MeetingRecorder -only-testing:MeetingRecorderTests/Integration
```

### UI Tests
```bash
# Run all UI tests
xcodebuild test -scheme MeetingRecorder -only-testing:MeetingRecorderUITests

# Run specific UI test class
xcodebuild test -scheme MeetingRecorder -only-testing:MeetingRecorderUITests/RecordingScreenUITests
```

### Run All Tests
```bash
xcodebuild test -scheme MeetingRecorder -destination 'platform=iOS Simulator,name=iPhone 14'
```

## Test Configuration

### In-Memory Testing
Unit and integration tests use in-memory Core Data stores to ensure:
- Fast test execution
- No side effects between tests
- Clean state for each test

### Mock Objects
Tests use mock implementations where appropriate:
- `MockTranscriptionService` - For testing recording without actual transcription
- `MockStorageManager` - For testing sync without actual storage operations

### Test Data
Helper methods create test data with realistic values:
- Test recordings with metadata
- Test transcript segments with timestamps
- Test speaker profiles
- Test notes and tags

## Test Coverage Goals

### Core Functionality (Priority 1)
- ✅ Recording state management
- ✅ Audio configuration
- ✅ Transcript generation
- ✅ Storage operations
- ✅ Sync queue management

### User Workflows (Priority 2)
- ✅ Complete recording flow
- ✅ Playback with transcript sync
- ✅ Export in multiple formats
- ✅ Offline scenarios

### UI Interactions (Priority 3)
- ✅ Recording controls
- ✅ List navigation and search
- ✅ Detail view interactions
- ✅ Settings management

## Best Practices

### Test Naming
- Use descriptive test names: `testRecordButtonStartsRecording`
- Follow pattern: `test[What]Does[Expected]`

### Test Structure
- Use Given-When-Then comments
- One assertion per logical concept
- Clean up resources in tearDown

### Async Testing
- Use `async/await` for asynchronous operations
- Set appropriate timeouts for UI tests
- Handle race conditions properly

### Accessibility
- Include accessibility tests for all UI components
- Verify VoiceOver labels exist
- Test with Dynamic Type

## Continuous Integration

Tests should be run:
- Before each commit (pre-commit hook)
- On pull requests (CI pipeline)
- Before releases (release checklist)

## Known Limitations

### Audio Testing
- Actual audio recording requires physical device or simulator with microphone access
- Tests verify configuration and state management, not actual audio quality

### Transcription Testing
- Real transcription requires Speech Framework authorization
- Tests verify data structures and flow, not actual transcription accuracy

### Cloud Sync Testing
- iCloud testing requires proper entitlements and account setup
- Tests verify queue management and conflict resolution logic

### UI Testing
- UI tests require specific accessibility identifiers in production code
- Some tests may need adjustment based on actual UI implementation

## Troubleshooting

### Tests Failing on CI
- Ensure simulator is properly configured
- Check for timing issues (increase timeouts if needed)
- Verify test data is properly cleaned up

### Flaky Tests
- Add explicit waits for asynchronous operations
- Use `waitForExistence(timeout:)` for UI elements
- Avoid hardcoded sleep() calls when possible

### Permission Issues
- Tests requiring permissions may need manual authorization on first run
- Use test schemes with proper entitlements

## Future Enhancements

- Add performance tests for large recording libraries
- Add snapshot tests for UI consistency
- Add load tests for concurrent operations
- Add security tests for data protection
- Add network condition simulation tests
