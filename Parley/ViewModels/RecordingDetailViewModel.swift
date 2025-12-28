//
//  RecordingDetailViewModel.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import AVFoundation
import os.log

/// ViewModel for managing recording detail UI state and playback
@MainActor
final class RecordingDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var recording: Recording?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // Playback state
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var currentSegmentID: UUID?
    
    // Edit mode
    @Published var isEditMode: Bool = false
    @Published var editedTranscript: [TranscriptSegment] = []
    
    // Notes management
    @Published var showAddNoteSheet: Bool = false
    @Published var editingNote: Note?
    
    // Tag management
    @Published var showAddTagSheet: Bool = false
    @Published var tagInput: String = ""
    @Published var availableTags: [String] = []
    
    // Export functionality
    @Published var showExportSheet: Bool = false
    @Published var showShareSheet: Bool = false
    @Published var shareURL: URL?
    
    // MARK: - Private Properties

    private let storageManager: StorageManagerProtocol
    private let recordingID: UUID
    private var cancellables = Set<AnyCancellable>()
    private let exportService = ExportService()
    private let logger = Logger(subsystem: "com.parley.app", category: "RecordingDetailViewModel")

    // Audio session state tracking
    private var previousAudioSessionCategory: AVAudioSession.Category?
    private var previousAudioSessionOptions: AVAudioSession.CategoryOptions = []
    
    // Audio player
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    
    // MARK: - Initialization
    
    init(recordingID: UUID, storageManager: StorageManagerProtocol) {
        self.recordingID = recordingID
        self.storageManager = storageManager
    }
    
    deinit {
        // Cleanup resources
        Task { @MainActor [weak self] in
            self?.cleanupPlayer()
        }
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        logger.info("RecordingDetailViewModel deinitialized")
    }
    
    // MARK: - Loading
    
    func loadRecording() async {
        isLoading = true
        errorMessage = nil
        
        do {
            recording = try await storageManager.getRecording(id: recordingID)
            
            if let recording = recording {
                editedTranscript = recording.transcript
                setupAudioPlayer(url: recording.audioFileURL)
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load recording: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    // MARK: - Audio Player Setup
    
    private func setupAudioPlayer(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        audioPlayer = player

        // Configure audio session for playback to use speaker phone
        configureAudioSessionForPlayback()

        // Add time observer for playback progress
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let timeUpdateHandler: @Sendable (CMTime) -> Void = { [weak self] time in
            Task { @MainActor [weak self] in
                self?.updatePlaybackTime(time)
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: timeUpdateHandler)

        // Observe player status
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                self?.handlePlaybackEnded()
            }
            .store(in: &cancellables)

        // Add audio interruption handling
        setupAudioInterruptionHandling()
    }

    private func configureAudioSessionForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Save previous audio session state for restoration
            previousAudioSessionCategory = audioSession.category
            previousAudioSessionOptions = audioSession.categoryOptions

            // Configure audio session for speaker playback
            try audioSession.setCategory(.playback, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            if #available(iOS 26.0, *) {
                try audioSession.setCategory(.playback, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            }
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Force speaker output by overriding the audio route
            try audioSession.overrideOutputAudioPort(.speaker)

            // Additional safeguard: Check current route and force speaker if needed
            let currentRoute = audioSession.currentRoute
            if currentRoute.outputs.first(where: { $0.portType == .builtInSpeaker }) == nil {
                try audioSession.overrideOutputAudioPort(.speaker)
            }

            logger.info("Audio session configured for playback with speaker output")
        } catch {
            logger.error("Failed to configure audio session for playback: \(error.localizedDescription)")
            ErrorLogger.log(error, context: "RecordingDetailViewModel.configureAudioSessionForPlayback")
        }
    }

    private func ensureSpeakerOutput() {
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Force speaker output if not already set
            try audioSession.overrideOutputAudioPort(.speaker)

            // Verify the output is actually routed to speaker
            let currentRoute = audioSession.currentRoute
            let isSpeakerActive = currentRoute.outputs.contains { $0.portType == .builtInSpeaker }

            if !isSpeakerActive {
                // Try again if speaker is not active
                try audioSession.overrideOutputAudioPort(.speaker)
                logger.warning("Had to force speaker output again - previous attempt may have failed")
            }

            logger.debug("Ensured audio output is routed to speaker")
        } catch {
            logger.error("Failed to ensure speaker output: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioInterruptionHandling() {
        // Handle audio interruptions (phone calls, alarms, etc.)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let self = self else { return }

                if let userInfo = notification.userInfo,
                   let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                   let type = AVAudioSession.InterruptionType(rawValue: typeValue) {

                    Task { @MainActor in
                        switch type {
                        case .began:
                            // Interruption began - pause playback
                            if self.isPlaying {
                                self.logger.info("Audio interruption began - pausing playback")
                                self.pause()
                            }

                        case .ended:
                            // Interruption ended - check if we should resume
                            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

                                if options.contains(.shouldResume) {
                                    self.logger.info("Audio interruption ended - resuming playback")
                                    self.play()
                                }
                            }

                        @unknown default:
                            break
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func cleanupPlayer() {
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        audioPlayer?.pause()
        audioPlayer = nil

        // Reset audio session when cleanup
        resetAudioSession()
    }

    private func resetAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()

            // Restore previous audio session state
            if let previousCategory = previousAudioSessionCategory {
                try audioSession.setCategory(previousCategory, options: previousAudioSessionOptions)
                logger.info("Restored audio session to previous category: \(previousCategory.rawValue)")
            }

            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            logger.info("Audio session reset successfully")
        } catch {
            logger.error("Failed to reset audio session: \(error.localizedDescription)")
            ErrorLogger.log(error, context: "RecordingDetailViewModel.resetAudioSession")
        }
    }
    
    // MARK: - Playback Control
    
    func togglePlayPause() {
        guard audioPlayer != nil else { return }
        
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        // Ensure audio is routed to speaker before playback
        ensureSpeakerOutput()

        audioPlayer?.play()
        isPlaying = true
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func skipForward() {
        guard let player = audioPlayer else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = min(currentTime + 15.0, recording?.duration ?? 0.0)
        seek(to: newTime)
    }
    
    func skipBackward() {
        guard let player = audioPlayer else { return }
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = max(currentTime - 15.0, 0.0)
        seek(to: newTime)
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        audioPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        updateCurrentSegment()
    }
    
    private func updatePlaybackTime(_ time: CMTime) {
        currentTime = CMTimeGetSeconds(time)
        updateCurrentSegment()
    }
    
    private func updateCurrentSegment() {
        guard let recording = recording else { return }
        
        // Find the segment that contains the current playback time
        currentSegmentID = recording.transcript.first { segment in
            let segmentEnd = segment.timestamp + segment.duration
            return currentTime >= segment.timestamp && currentTime < segmentEnd
        }?.id
    }
    
    private func handlePlaybackEnded() {
        isPlaying = false
        currentTime = 0.0
        audioPlayer?.seek(to: .zero)
    }
    
    // MARK: - Transcript Editing
    
    func toggleEditMode() {
        if isEditMode {
            // Save changes
            saveTranscriptEdits()
        } else {
            // Enter edit mode
            editedTranscript = recording?.transcript ?? []
        }
        isEditMode.toggle()
    }
    
    func updateSegmentText(_ segmentID: UUID, newText: String) {
        if let index = editedTranscript.firstIndex(where: { $0.id == segmentID }) {
            var segment = editedTranscript[index]
            segment = TranscriptSegment(
                id: segment.id,
                text: newText,
                timestamp: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence,
                speakerID: segment.speakerID,
                isEdited: true
            )
            editedTranscript[index] = segment
        }
    }
    
    func updateSegmentSpeaker(_ segmentID: UUID, newSpeakerID: String) {
        if let index = editedTranscript.firstIndex(where: { $0.id == segmentID }) {
            var segment = editedTranscript[index]
            segment = TranscriptSegment(
                id: segment.id,
                text: segment.text,
                timestamp: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence,
                speakerID: newSpeakerID,
                isEdited: true
            )
            editedTranscript[index] = segment
        }
    }
    
    private func saveTranscriptEdits() {
        guard var recording = recording else { return }
        
        recording.transcript = editedTranscript
        recording.lastModified = Date()
        
        Task {
            do {
                try await storageManager.updateRecording(recording)
                self.recording = recording
            } catch {
                errorMessage = "Failed to save transcript edits: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Notes Management
    
    func addNote(text: String) {
        guard var recording = recording else { return }
        
        let note = Note(text: text, timestamp: isPlaying ? currentTime : nil)
        recording.notes.append(note)
        recording.lastModified = Date()
        
        Task {
            do {
                try await storageManager.updateRecording(recording)
                self.recording = recording
            } catch {
                errorMessage = "Failed to add note: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func updateNote(_ noteID: UUID, text: String) {
        guard var recording = recording else { return }
        
        if let index = recording.notes.firstIndex(where: { $0.id == noteID }) {
            var note = recording.notes[index]
            note = Note(id: note.id, text: text, timestamp: note.timestamp, createdAt: note.createdAt)
            recording.notes[index] = note
            recording.lastModified = Date()
            
            Task {
                do {
                    try await storageManager.updateRecording(recording)
                    self.recording = recording
                } catch {
                    errorMessage = "Failed to update note: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    func deleteNote(_ noteID: UUID) {
        guard var recording = recording else { return }
        
        recording.notes.removeAll { $0.id == noteID }
        recording.lastModified = Date()
        
        Task {
            do {
                try await storageManager.updateRecording(recording)
                self.recording = recording
            } catch {
                errorMessage = "Failed to delete note: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Tag Management
    
    func loadAvailableTags() async {
        do {
            let allRecordings = try await storageManager.getAllRecordings(sortedBy: .dateDescending)
            let allTags = Set(allRecordings.flatMap { $0.tags })
            availableTags = Array(allTags).sorted()
        } catch {
            // Silently fail - not critical
        }
    }
    
    func addTag(_ tag: String) {
        guard var recording = recording else { return }
        
        let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty, !recording.tags.contains(trimmedTag) else { return }
        
        recording.tags.append(trimmedTag)
        recording.lastModified = Date()
        
        Task {
            do {
                try await storageManager.updateRecording(recording)
                self.recording = recording
                tagInput = ""
            } catch {
                errorMessage = "Failed to add tag: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    func removeTag(_ tag: String) {
        guard var recording = recording else { return }
        
        recording.tags.removeAll { $0 == tag }
        recording.lastModified = Date()
        
        Task {
            do {
                try await storageManager.updateRecording(recording)
                self.recording = recording
            } catch {
                errorMessage = "Failed to remove tag: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    var formattedDuration: String {
        formatTime(recording?.duration ?? 0.0)
    }
    
    var playbackProgress: Double {
        guard let duration = recording?.duration, duration > 0 else { return 0.0 }
        return currentTime / duration
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    func getSpeakerName(for speakerID: String) -> String {
        recording?.speakers.first { $0.id == speakerID }?.displayName ?? speakerID
    }
    
    // MARK: - Export Functionality
    
    func exportRecording(format: ExportService.ExportFormat) {
        guard let recording = recording else { return }
        
        Task {
            do {
                let fileURL: URL
                
                switch format {
                case .plainText:
                    fileURL = try exportService.generatePlainText(for: recording)
                case .markdown:
                    fileURL = try exportService.generateMarkdown(for: recording)
                case .audio:
                    fileURL = try exportService.generateAudio(for: recording)
                }
                
                // Update UI on main thread
                await MainActor.run {
                    self.shareURL = fileURL
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to export recording: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    func cleanupExportFiles() {
        exportService.cleanupTemporaryFiles()
    }
    
    // MARK: - Cleanup
}
