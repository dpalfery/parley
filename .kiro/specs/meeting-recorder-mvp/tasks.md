# Implementation Plan

- [x] 1. Set up project structure and core interfaces





  - Create Xcode project with SwiftUI app template targeting iOS 16+
  - Configure project capabilities: Microphone, Speech Recognition, iCloud, Background Modes (Audio)
  - Create folder structure: Models/, Services/, Views/, ViewModels/, Utilities/, Resources/
  - Define protocol interfaces for RecordingServiceProtocol, TranscriptionServiceProtocol, SpeakerServiceProtocol, StorageManagerProtocol, CloudSyncServiceProtocol
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 2. Implement data models and Core Data stack




  - [x] 2.1 Create Core Data model file with RecordingEntity and SpeakerProfileEntity


    - Define RecordingEntity attributes: id, title, date, duration, audioFileName, transcriptData, speakersData, tagsData, notesData, fileSize, isSynced, lastModified, searchableContent
    - Define SpeakerProfileEntity attributes: id, displayName, voiceCharacteristics, createdAt, lastUsed
    - Configure indexes on searchableContent and date fields for query performance
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  - [x] 2.2 Create Swift model structs


    - Implement Recording, TranscriptSegment, SpeakerProfile, Note, SpeakerSegment structs with Codable conformance
    - Implement RecordingState, AudioQuality, SyncStatus, ConflictResolution enums
    - Add computed properties and helper methods for model transformations
    - _Requirements: 1.1, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4, 4.5_
  - [x] 2.3 Implement Core Data persistence manager


    - Create PersistenceController with NSPersistentContainer setup
    - Implement entity-to-model and model-to-entity conversion methods
    - Configure Core Data for iCloud sync with NSPersistentCloudKitContainer
    - Add error handling for Core Data operations
    - _Requirements: 5.1, 5.2, 6.1, 6.2_

- [x] 3. Build Recording Service





  - [x] 3.1 Implement audio session configuration


    - Configure AVAudioSession with .record category and .allowBluetooth options
    - Request microphone permission with proper usage description
    - Handle audio session interruptions (phone calls, alarms)
    - Implement session activation and deactivation logic
    - _Requirements: 1.1, 1.4_
  - [x] 3.2 Implement core recording functionality

    - Create RecordingService class conforming to RecordingServiceProtocol
    - Implement startRecording method with AVAudioRecorder setup for M4A format
    - Configure audio quality settings (64, 128, 256 kbps) based on AudioQuality enum
    - Implement stopRecording method that finalizes audio file and returns Recording model
    - Add cancelRecording method to discard recording without saving
    - _Requirements: 1.1, 1.4, 2.1_
  - [x] 3.3 Implement pause and resume functionality

    - Add pauseRecording method that suspends AVAudioRecorder
    - Add resumeRecording method that continues recording to same file
    - Insert timestamp markers in recording metadata at pause/resume points
    - Maintain accurate duration tracking across pause/resume cycles
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  - [x] 3.4 Add real-time audio level monitoring

    - Enable metering on AVAudioRecorder
    - Implement timer-based updateMeters calls at 60Hz
    - Publish normalized audio level values (0.0 to 1.0) via Combine
    - Calculate and publish elapsed recording time
    - _Requirements: 1.2, 1.3_
  - [x] 3.5 Implement background recording support


    - Configure background audio capability in project settings
    - Maintain active audio session when app backgrounds
    - Handle app state transitions without interrupting recording
    - Test recording continuation during backgrounding
    - _Requirements: 1.5_

- [x] 4. Build Transcription Service




  - [x] 4.1 Implement Speech Framework integration


    - Create TranscriptionService class conforming to TranscriptionServiceProtocol
    - Request speech recognition authorization with proper usage description
    - Initialize SFSpeechRecognizer with device locale
    - Handle speech recognition unavailability gracefully
    - _Requirements: 3.1_
  - [x] 4.2 Implement real-time transcription

    - Create SFSpeechAudioBufferRecognitionRequest for live audio processing
    - Configure recognition request for on-device processing
    - Process audio buffers from recording service in real-time
    - Publish partial transcription results as they arrive
    - _Requirements: 3.2_
  - [x] 4.3 Generate transcript segments with metadata

    - Convert SFTranscriptionResult to TranscriptSegment models
    - Calculate accurate timestamps for each segment relative to recording start
    - Extract confidence scores from recognition results
    - Apply automatic punctuation and capitalization
    - Mark low-confidence segments (< 0.5 confidence) with visual indicator flag
    - _Requirements: 3.3, 3.4, 3.5_
  - [x] 4.4 Handle transcription lifecycle and limits

    - Implement 1-minute segment processing to avoid Speech Framework limits
    - Restart recognition request for continuous long recordings
    - Handle recognition errors and publish error states
    - Implement stopTranscription method to clean up resources
    - _Requirements: 3.1, 3.2_

- [x] 5. Build Speaker Service





  - [x] 5.1 Implement basic speaker diarization


    - Create SpeakerService class conforming to SpeakerServiceProtocol
    - Implement energy-based voice activity detection (VAD) on audio buffer
    - Detect speaker changes using pause duration and energy level shifts
    - Generate SpeakerSegment models with start/end times
    - _Requirements: 4.1, 4.3_
  - [x] 5.2 Implement speaker identification and labeling


    - Assign sequential speaker IDs (Speaker 1, Speaker 2, etc.) to detected segments
    - Associate speaker IDs with transcript segments based on timestamps
    - Maintain consistent speaker labels throughout recording session
    - Publish speaker change events for UI indicators
    - _Requirements: 4.2, 4.3, 4.4_
  - [x] 5.3 Build speaker profile management


    - Implement speaker profile creation with basic voice characteristics
    - Store speaker profiles in Core Data using SpeakerProfileEntity
    - Implement assignSpeakerToSegment to allow post-recording name assignment
    - Implement updateSpeakerName to modify speaker display names
    - Update lastUsed timestamp when speaker profile is referenced
    - _Requirements: 4.5_

- [x] 6. Build Storage Manager




  - [x] 6.1 Implement local file storage operations


    - Create StorageManager class conforming to StorageManagerProtocol
    - Implement file system structure: Documents/Recordings/{uuid}/audio.m4a
    - Implement saveRecording method that writes audio file and metadata JSON
    - Enable NSFileProtectionComplete for data protection
    - Calculate and store file sizes for storage tracking
    - _Requirements: 5.1, 5.2, 12.2_
  - [x] 6.2 Implement Core Data CRUD operations

    - Implement saveRecording to persist RecordingEntity with all metadata
    - Implement getRecording to fetch single recording by UUID
    - Implement getAllRecordings with sorting options (date, title, duration)
    - Implement updateRecording to modify existing recordings
    - Implement deleteRecording with local and cloud deletion options
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 12.3, 12.4_
  - [x] 6.3 Implement search and filtering

    - Build searchRecordings using NSPredicate for full-text search on searchableContent
    - Implement tag-based filtering with NSPredicate
    - Implement date range filtering
    - Index transcript content in searchableContent field for performance
    - _Requirements: 7.4, 7.5_
  - [x] 6.4 Implement storage usage tracking

    - Calculate total storage used by all recordings
    - Implement getStorageUsage to return total size and per-recording sizes
    - Display storage metrics in bytes, KB, MB, or GB as appropriate
    - _Requirements: 12.1, 12.2_
  - [x] 6.5 Implement automatic cleanup policies

    - Add user preference for auto-cleanup threshold (days)
    - Implement cleanup logic to delete local files older than threshold
    - Preserve iCloud copies when deleting local files
    - Run cleanup check on app launch and after each recording save
    - _Requirements: 12.5_
-

- [x] 7. Build Cloud Sync Service



  - [x] 7.1 Implement iCloud Drive integration


    - Create CloudSyncService class conforming to CloudSyncServiceProtocol
    - Configure NSFileManager ubiquityContainerURL for iCloud Drive access
    - Create iCloud directory structure: MeetingRecorder/Recordings/{uuid}/
    - Check iCloud availability using NSFileManager.ubiquityIdentityToken
    - _Requirements: 6.1, 6.2, 6.3_
  - [x] 7.2 Implement upload functionality

    - Implement syncRecording to upload audio and metadata files to iCloud
    - Use NSFileCoordinator for coordinated file access
    - Implement progress tracking for upload operations
    - Update isSynced flag in Core Data after successful upload
    - _Requirements: 6.1, 6.2, 6.4_
  - [x] 7.3 Implement sync queue and offline handling

    - Create sync queue to track pending uploads
    - Monitor network connectivity using NWPathMonitor
    - Queue sync operations when offline, process when connectivity restored
    - Publish sync status updates (idle, syncing, synced, error, offline)
    - _Requirements: 6.3, 6.4_
  - [x] 7.4 Implement sync settings and controls

    - Add user preference to enable/disable iCloud sync
    - Implement enableSync and disableSync methods
    - Implement syncAll to batch-sync all unsynced recordings
    - Handle iCloud account changes and re-authentication
    - _Requirements: 6.5_

- [x] 8. Build recording UI





  - [x] 8.1 Create recording view and view model


    - Create RecordingView SwiftUI view with record, pause, resume, stop buttons
    - Create RecordingViewModel with @Published properties for state, duration, audioLevel
    - Inject RecordingService and TranscriptionService dependencies
    - Implement view lifecycle methods to handle recording state
    - _Requirements: 1.1, 2.1, 2.2_
  - [x] 8.2 Implement recording controls and indicators

    - Add large record button that starts recording on tap
    - Display elapsed time in MM:SS format, updating every second
    - Show pause/resume buttons when recording is active
    - Add stop button to finalize recording
    - Display recording state indicator (idle, recording, paused, processing)
    - _Requirements: 1.2, 2.2_
  - [x] 8.3 Add audio level visualization


    - Create audio level meter view with animated bars or waveform
    - Bind audio level to RecordingViewModel.audioLevel publisher
    - Update visualization at 60 FPS for smooth animation
    - Use color coding (green for normal, yellow for high, red for clipping)
    - _Requirements: 1.3_
  - [x] 8.4 Display real-time transcription

    - Add scrollable text view for live transcript display
    - Bind transcript segments to RecordingViewModel.transcriptSegments
    - Auto-scroll to latest transcript segment as text appears
    - Highlight low-confidence words with different styling
    - Display speaker labels for each transcript segment
    - _Requirements: 3.2, 3.5, 4.2, 4.3_
  - [x] 8.5 Add notes input during recording

    - Add text field or button to open notes sheet during recording
    - Capture current timestamp when note is created
    - Save notes to recording model
    - Display notes count indicator on recording view
    - _Requirements: 11.1, 11.2_
- [x] 9. Build recording list UI




- [ ] 9. Build recording list UI

  - [x] 9.1 Create recording list view and view model


    - Create RecordingListView with LazyVStack for performance
    - Create RecordingListViewModel with @Published recordings array
    - Inject StorageManager dependency
    - Load recordings on view appear, sorted by date descending
    - _Requirements: 7.1, 7.2_
  - [x] 9.2 Implement recording list items


    - Create RecordingRowView displaying title, date, duration, tags
    - Format date as relative time (Today, Yesterday, date)
    - Format duration as HH:MM:SS or MM:SS
    - Display sync status icon (synced, syncing, offline)
    - Add navigation link to recording detail view
    - _Requirements: 7.2, 7.3_
  - [x] 9.3 Add search functionality

    - Add search bar at top of list view
    - Implement search query binding to view model
    - Filter recordings based on search text (title and transcript content)
    - Update list dynamically as user types
    - _Requirements: 7.5_
  - [x] 9.4 Add filtering options


    - Add filter button to show filter sheet
    - Implement tag filter with multi-select
    - Implement date range filter with date pickers
    - Apply filters to recording list query
    - Display active filter indicators
    - _Requirements: 7.4_
-

- [x] 10. Build recording detail UI




  - [x] 10.1 Create recording detail view and view model


    - Create RecordingDetailView displaying full recording information
    - Create RecordingDetailViewModel with @Published recording property
    - Load recording by ID from StorageManager
    - Display title, date, duration, file size, tags, speakers
    - _Requirements: 7.3, 8.1_
  - [x] 10.2 Implement audio playback controls


    - Add AVPlayer for audio playback
    - Create playback controls: play/pause, skip forward 15s, skip backward 15s
    - Display playback progress with seekable slider
    - Show current playback time and total duration
    - _Requirements: 8.1, 8.2, 8.3, 8.5_
  - [x] 10.3 Implement synchronized transcript display


    - Display full transcript with speaker labels and timestamps
    - Highlight current transcript segment during playback
    - Implement tap-to-seek: jump playback to tapped segment timestamp
    - Auto-scroll transcript to keep highlighted segment visible
    - _Requirements: 8.2, 8.4_
  - [x] 10.4 Add transcript editing functionality


    - Add edit mode toggle button
    - Make transcript text editable in edit mode
    - Allow speaker label modification in edit mode
    - Preserve timestamps during editing
    - Save edited transcript to storage on save button tap
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_
  - [x] 10.5 Implement notes management


    - Display existing notes with timestamps
    - Add button to create new note
    - Allow editing and deleting notes
    - Save notes changes to recording model
    - _Requirements: 11.2, 11.3, 11.4_
  - [x] 10.6 Add tag management


    - Display current tags as chips/badges
    - Add button to add new tags
    - Implement tag input with autocomplete from existing tags
    - Allow tag removal
    - Save tag changes to recording model
    - _Requirements: 5.4_

- [x] 11. Build export and sharing functionality




  - [x] 11.1 Implement export format generators


    - Create ExportService with methods for each format
    - Implement generatePlainText to create TXT file with transcript and timestamps
    - Implement generateMarkdown to create MD file with formatted headings and speaker labels
    - Implement generateAudio to copy M4A file for sharing
    - Include notes in exported text formats
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_
  - [x] 11.2 Implement share sheet integration


    - Add export button to recording detail view
    - Show action sheet with export format options
    - Generate selected format file in temporary directory
    - Present iOS share sheet (UIActivityViewController) with generated file
    - Clean up temporary files after sharing
    - _Requirements: 10.5_
-

- [x] 12. Build settings and storage management UI



  - [x] 12.1 Create settings view


    - Create SettingsView with sections for audio, transcription, storage, sync
    - Add audio quality picker (low, medium, high)
    - Add iCloud sync toggle
    - Add storage usage display
    - Add auto-cleanup threshold picker (7, 14, 30, 60, 90 days, or never)
    - _Requirements: 1.4, 6.5, 12.1, 12.5_
  - [x] 12.2 Implement storage management section


    - Display total storage used by recordings
    - Add button to view detailed storage breakdown
    - Add manual cleanup button to delete local copies of synced recordings
    - Show confirmation dialog before cleanup operations
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

- [x] 13. Implement app-wide error handling and user feedback




  - [x] 13.1 Create error handling infrastructure


    - Define RecordingError, TranscriptionError, StorageError, SyncError enums
    - Implement localized error descriptions
    - Create ErrorAlert view modifier for consistent error presentation
    - Add error logging using OSLog
    - _Requirements: All requirements (error handling)_
  - [x] 13.2 Add user feedback mechanisms


    - Implement toast notifications for success operations
    - Add loading indicators for async operations
    - Show progress views for long-running tasks (sync, export)
    - Add haptic feedback for key interactions
    - _Requirements: All requirements (user feedback)_
-

- [x] 14. Implement app navigation and main structure



  - [x] 14.1 Create app entry point and navigation


    - Create MeetingRecorderApp with @main attribute
    - Set up NavigationStack with RecordingListView as root
    - Configure app-wide environment objects (PersistenceController, services)
    - Add tab bar or navigation structure for main sections
    - _Requirements: All requirements (app structure)_
  - [x] 14.2 Handle app lifecycle and permissions


    - Request microphone permission on first launch
    - Request speech recognition permission on first transcription
    - Handle permission denial with settings deep-link
    - Implement app state restoration for interrupted recordings
    - _Requirements: 1.1, 3.1_
-

- [x] 15. Polish and accessibility




  - [x] 15.1 Implement accessibility features


    - Add VoiceOver labels to all interactive elements
    - Ensure recording state changes are announced
    - Make transcript content accessible with VoiceOver
    - Test with Dynamic Type at various sizes
    - Verify color contrast meets WCAG AA standards
    - _Requirements: All requirements (accessibility)_
  - [x] 15.2 Add dark mode support


    - Define color assets for light and dark modes
    - Test all views in dark mode
    - Ensure audio level visualizations work in both modes
    - Verify recording indicators are visible in both modes
    - _Requirements: All requirements (UI polish)_
  - [x] 15.3 Performance optimization


    - Profile app with Instruments for memory leaks
    - Optimize Core Data fetch requests with proper predicates
    - Implement lazy loading for large transcript displays
    - Test with long recordings (2+ hours) and large libraries (100+ recordings)
    - _Requirements: All requirements (performance)_

- [x] 16. Testing and quality assurance





  - [x]  16.1 Write unit tests for services


    - Test RecordingService state transitions and audio configuration
    - Test TranscriptionService segment generation and timestamp accuracy
    - Test SpeakerService diarization logic
    - Test StorageManager CRUD operations and search
    - Test CloudSyncService queue management and conflict resolution
    - _Requirements: All requirements (testing)_


  - [ ] 16.2 Write integration tests
    - Test end-to-end recording flow: start → transcribe → save → sync
    - Test playback flow: load → play → seek
    - Test export flow: generate → share


    - Test offline scenarios and sync recovery
    - _Requirements: All requirements (testing)_
  - [ ] 16.3 Perform UI testing
    - Test recording screen interactions
    - Test recording list navigation and search
    - Test recording detail playback and editing
    - Test settings and storage management
    - _Requirements: All requirements (testing)_
