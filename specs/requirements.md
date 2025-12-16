# Requirements Document

## Introduction

The Meeting Recorder MVP is a mobile application (iOS-first) that enables users to record meetings with real-time transcription, basic speaker identification, and cloud storage integration. The MVP focuses on core recording and transcription functionality using native device capabilities, with local storage and iCloud sync. This phase establishes the foundation for future enhancements including Apple Watch integration, advanced speaker profiles, and AI transcription fallback options.

## Glossary

- **Recording System**: The mobile application component responsible for capturing audio input
- **Transcription Engine**: The software module that converts spoken audio to written text using device native capabilities
- **Speaker Diarization Module**: The component that identifies and separates different speakers in an audio recording
- **Storage Manager**: The system component that handles local file storage and cloud synchronization
- **Audio Buffer**: Temporary memory storage for captured audio data during recording
- **Transcript Segment**: A timestamped portion of transcribed text associated with a specific speaker
- **Recording Session**: A single continuous or paused recording instance from start to stop
- **Voice Profile**: An acoustic model representing an individual speaker's characteristics
- **Tag**: A user-defined label for categorizing and organizing recordings
- **iCloud Sync**: Apple's cloud storage service integration for automatic file backup
- **Native Transcription**: Speech-to-text conversion using iOS Speech Recognition Framework

## Requirements

### Requirement 1

**User Story:** As a meeting participant, I want to start recording audio quickly, so that I can capture important discussions without delay

#### Acceptance Criteria

1. WHEN the user taps the record button, THE Recording System SHALL begin capturing audio within 2 seconds
2. WHILE recording is active, THE Recording System SHALL display a visual indicator showing elapsed time in minutes and seconds
3. WHILE recording is active, THE Recording System SHALL display real-time audio level indicators
4. THE Recording System SHALL support audio quality settings of 64 kbps, 128 kbps, and 256 kbps
5. WHEN the user backgrounds the application during recording, THE Recording System SHALL continue capturing audio without interruption

### Requirement 2

**User Story:** As a meeting participant, I want to pause and resume recordings, so that I can exclude breaks or off-topic discussions

#### Acceptance Criteria

1. WHILE a recording is active, WHEN the user taps the pause button, THE Recording System SHALL suspend audio capture within 500 milliseconds
2. WHILE a recording is paused, THE Recording System SHALL display the paused state with total elapsed recording time
3. WHILE a recording is paused, WHEN the user taps the resume button, THE Recording System SHALL continue audio capture within 500 milliseconds
4. THE Recording System SHALL maintain a single continuous recording file across pause and resume actions
5. THE Recording System SHALL insert timestamp markers in the transcript at each pause and resume point

### Requirement 3

**User Story:** As a meeting participant, I want real-time transcription of the audio, so that I can follow along and verify content is being captured

#### Acceptance Criteria

1. WHEN recording begins, THE Transcription Engine SHALL start converting audio to text using iOS Speech Recognition Framework
2. WHILE recording is active, THE Transcription Engine SHALL display transcribed text with a maximum delay of 3 seconds from spoken words
3. THE Transcription Engine SHALL apply automatic punctuation and capitalization to transcribed text
4. THE Transcription Engine SHALL associate each transcript segment with a timestamp accurate to within 1 second
5. WHEN transcription confidence is below 50 percent, THE Transcription Engine SHALL mark the low-confidence words with a visual indicator

### Requirement 4

**User Story:** As a meeting participant, I want the system to identify different speakers, so that I can distinguish who said what in the transcript

#### Acceptance Criteria

1. WHILE recording is active, THE Speaker Diarization Module SHALL detect speaker changes and create separate transcript segments
2. THE Speaker Diarization Module SHALL label identified speakers as Speaker 1, Speaker 2, and so forth in sequential order
3. WHEN a speaker change is detected, THE Speaker Diarization Module SHALL display a visual indicator within 2 seconds
4. THE Speaker Diarization Module SHALL maintain speaker labels consistently throughout a single recording session
5. AFTER recording completion, THE Speaker Diarization Module SHALL allow users to assign custom names to speaker labels

### Requirement 5

**User Story:** As a meeting participant, I want to save recordings with metadata, so that I can organize and find them later

#### Acceptance Criteria

1. WHEN the user stops recording, THE Storage Manager SHALL save the audio file in M4A format to local storage within 5 seconds
2. WHEN the user stops recording, THE Storage Manager SHALL save transcript data in JSON format with timestamps and speaker labels
3. THE Storage Manager SHALL automatically generate metadata including date, time, duration, and file size for each recording
4. THE Storage Manager SHALL allow users to add custom tags to recordings before or after saving
5. THE Storage Manager SHALL create a unique identifier for each recording session

### Requirement 6

**User Story:** As a meeting participant, I want my recordings automatically backed up to iCloud, so that I don't lose important content if my device fails

#### Acceptance Criteria

1. WHEN a recording is saved locally, THE Storage Manager SHALL initiate iCloud sync within 30 seconds if network connectivity exists
2. THE Storage Manager SHALL sync both audio files and transcript data to the user's iCloud Drive
3. WHEN network connectivity is unavailable, THE Storage Manager SHALL queue recordings for sync and retry when connectivity is restored
4. THE Storage Manager SHALL display sync status indicators showing pending, in-progress, and completed states
5. THE Storage Manager SHALL allow users to disable iCloud sync through application settings

### Requirement 7

**User Story:** As a meeting participant, I want to browse my past recordings, so that I can review previous meetings

#### Acceptance Criteria

1. THE Recording System SHALL display a list of all recordings sorted by date with most recent first
2. THE Recording System SHALL display recording title, date, duration, and tag information for each list item
3. WHEN the user taps a recording in the list, THE Recording System SHALL open a detail view within 1 second
4. THE Recording System SHALL allow users to filter recordings by date range or tag
5. THE Recording System SHALL provide a search function that matches text against recording titles and transcript content

### Requirement 8

**User Story:** As a meeting participant, I want to play back recordings with synchronized transcript, so that I can review specific parts of the meeting

#### Acceptance Criteria

1. WHEN the user taps play on a recording, THE Recording System SHALL begin audio playback within 1 second
2. WHILE audio is playing, THE Recording System SHALL highlight the corresponding transcript text synchronized to within 1 second
3. THE Recording System SHALL provide playback controls including play, pause, skip forward 15 seconds, and skip backward 15 seconds
4. WHEN the user taps a transcript segment, THE Recording System SHALL jump audio playback to that timestamp within 500 milliseconds
5. THE Recording System SHALL display playback progress with a seekable timeline showing total duration

### Requirement 9

**User Story:** As a meeting participant, I want to edit transcripts after recording, so that I can correct any transcription errors

#### Acceptance Criteria

1. WHEN viewing a recording detail, THE Recording System SHALL provide an edit mode for transcript text
2. WHILE in edit mode, THE Recording System SHALL allow users to modify transcript text while preserving timestamps
3. WHILE in edit mode, THE Recording System SHALL allow users to modify speaker labels
4. WHEN the user saves transcript edits, THE Storage Manager SHALL update the transcript file within 2 seconds
5. WHEN the user saves transcript edits, THE Storage Manager SHALL sync the updated transcript to iCloud if sync is enabled

### Requirement 10

**User Story:** As a meeting participant, I want to export recordings in different formats, so that I can share or archive meeting content

#### Acceptance Criteria

1. THE Recording System SHALL provide export options for plain text, Markdown, and audio file formats
2. WHEN the user selects plain text export, THE Recording System SHALL generate a TXT file with transcript content and timestamps
3. WHEN the user selects Markdown export, THE Recording System SHALL generate an MD file with formatted headings for speakers and timestamps
4. WHEN the user selects audio export, THE Recording System SHALL provide the M4A audio file
5. THE Recording System SHALL allow users to share exported files through iOS share sheet to email, messaging, or other applications

### Requirement 11

**User Story:** As a meeting participant, I want to add notes during or after recording, so that I can capture additional context or action items

#### Acceptance Criteria

1. WHILE recording is active, THE Recording System SHALL provide a notes input field accessible without stopping the recording
2. WHEN the user adds a note during recording, THE Recording System SHALL associate the note with the current timestamp
3. AFTER recording completion, THE Recording System SHALL allow users to add or edit notes in the recording detail view
4. THE Recording System SHALL display notes alongside transcript content with their associated timestamps
5. WHEN exporting a recording, THE Recording System SHALL include notes in the exported content

### Requirement 12

**User Story:** As a meeting participant, I want to manage my local storage, so that I can control how much space recordings consume

#### Acceptance Criteria

1. THE Storage Manager SHALL display total storage used by recordings in the application settings
2. THE Storage Manager SHALL display storage used per individual recording in the recording detail view
3. THE Storage Manager SHALL allow users to delete individual recordings from local storage
4. WHEN a recording is deleted locally and exists in iCloud, THE Storage Manager SHALL prompt the user to confirm deletion from both locations or local only
5. THE Storage Manager SHALL provide an automatic cleanup policy option to delete local copies of recordings older than a user-specified number of days while retaining iCloud copies
