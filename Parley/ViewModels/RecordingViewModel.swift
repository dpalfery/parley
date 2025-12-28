//
//  RecordingViewModel.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import SwiftUI
import UIKit
import AVFoundation

/// ViewModel for managing recording UI state and coordinating recording services
@MainActor
final class RecordingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var recordingState: RecordingState = .idle
    @Published var duration: TimeInterval = 0.0
    @Published var audioLevel: Float = 0.0
    @Published var transcriptSegments: [TranscriptSegment] = []
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var notes: [Note] = []
    @Published var showNotesSheet: Bool = false
    
    // MARK: - Private Properties
    
    private let recordingService: RecordingServiceProtocol
    private let transcriptionService: TranscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentRecordingSession: RecordingSession?
    private var stateRestorationManager: StateRestorationManager?
    private var recordingStartTime: Date?
    private let permissionManager: PermissionManager
    
    private var autoSaveTimer: Timer?

    // MARK: - Initialization
    
    init(
        recordingService: RecordingServiceProtocol,
        transcriptionService: TranscriptionServiceProtocol,
        stateRestorationManager: StateRestorationManager? = nil,
        permissionManager: PermissionManager
    ) {
        self.recordingService = recordingService
        self.transcriptionService = transcriptionService
        self.stateRestorationManager = stateRestorationManager
        self.permissionManager = permissionManager
        
        setupBindings()
        setupStateObservation()
    }
    
    // MARK: - State Observation
    
    private func setupStateObservation() {
        // Observe recording state changes to save state for restoration
        recordingService.recordingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func handleStateChange(_ state: RecordingState) {
        saveStateIfNeeded(state: state)
        
        // Manage auto-save timer
        if state == .recording {
            startAutoSaveTimer()
        } else {
            stopAutoSaveTimer()
        }
    }
    
    private func startAutoSaveTimer() {
        stopAutoSaveTimer()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.saveStateIfNeeded(state: self.recordingState)
            }
        }
    }
    
    private func stopAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
    
    private func saveStateIfNeeded(state: RecordingState) {
        guard let stateRestorationManager = stateRestorationManager,
              let session = currentRecordingSession,
              let startTime = recordingStartTime else {
            return
        }
        
        // Save state when recording or paused (not idle or processing)
        if state == .recording || state == .paused {
            stateRestorationManager.saveRecordingState(
                recordingID: session.id,
                startTime: startTime,
                duration: duration,
                state: state,
                audioFileName: session.audioFileURL.lastPathComponent,
                transcript: transcriptSegments
            )
        } else if state == .idle {
            // Clear state when recording completes
            stateRestorationManager.clearRecordingState()
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Bind recording state with accessibility announcements
        recordingService.recordingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.recordingState = newState
                self?.announceStateChange(newState)
            }
            .store(in: &cancellables)
        
        // Bind audio level
        recordingService.audioLevel
            .receive(on: DispatchQueue.main)
            .map { linearLevel in
                guard linearLevel > 0 else { return 0.0 }
                let db = 20 * log10(linearLevel)
                let minDb: Float = -60.0
                return max(0.0, min(1.0, (db - minDb) / (0.0 - minDb)))
            }
            .assign(to: &$audioLevel)
        
        // Bind duration
        recordingService.duration
            .receive(on: DispatchQueue.main)
            .assign(to: &$duration)
        
        // Bind transcript segments
        transcriptionService.transcriptSegments
            .receive(on: DispatchQueue.main)
            .assign(to: &$transcriptSegments)
            
        // Bind audio buffer stream to transcription service
        recordingService.audioBufferPublisher
            .sink { [weak self] buffer in
                self?.transcriptionService.processAudioBuffer(buffer)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Accessibility
    
    private func announceStateChange(_ state: RecordingState) {
        let announcement: String
        switch state {
        case .idle:
            announcement = "Ready to record"
        case .recording:
            announcement = "Recording started"
        case .paused:
            announcement = "Recording paused"
        case .processing:
            announcement = "Processing recording"
        }
        
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    // MARK: - Recording Actions
    
    func startRecording(quality: AudioQuality = .medium) {
        print("🎙️ DEBUG: startRecording() called")
        Task {
            let hasPermission = await permissionManager.requestMicrophonePermission()
            guard hasPermission else { return }
            
            do {
                // Start transcription first (setup request)
                try await transcriptionService.startLiveTranscription()
                
                print("🎙️ DEBUG: About to call recordingService.startRecording()")
                currentRecordingSession = try await recordingService.startRecording(quality: quality)
                print("🎙️ DEBUG: Recording started successfully, session: \(currentRecordingSession?.id.uuidString ?? "nil")")
                recordingStartTime = Date()
            } catch {
                print("🎙️ DEBUG: Error starting recording: \(error)")
                handleError(error)
            }
        }
    }
    
    func pauseRecording() {
        Task {
            do {
                try await recordingService.pauseRecording()
            } catch {
                handleError(error)
            }
        }
    }
    
    func resumeRecording() {
        Task {
            do {
                try await recordingService.resumeRecording()
            } catch {
                handleError(error)
            }
        }
    }
    
    func stopRecording() async -> Recording? {
        do {
            let recording = try await recordingService.stopRecording()
            await transcriptionService.stopTranscription()
            
            // Add notes to recording
            var updatedRecording = recording
            updatedRecording.notes = notes
            // Attach the final transcript
            updatedRecording.transcript = await transcriptionService.getFullTranscript()
            
            // Clear state restoration
            stateRestorationManager?.clearRecordingState()
            
            // Reset state
            notes = []
            currentRecordingSession = nil
            recordingStartTime = nil
            
            return updatedRecording
        } catch {
            handleError(error)
            return nil
        }
    }
    
    func cancelRecording() {
        Task {
            do {
                try await recordingService.cancelRecording()
                await transcriptionService.stopTranscription()
                
                // Clear state restoration
                stateRestorationManager?.clearRecordingState()
                
                notes = []
                currentRecordingSession = nil
                recordingStartTime = nil
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - Notes Management
    
    func addNote(text: String) {
        let note = Note(
            text: text,
            timestamp: recordingState == .recording || recordingState == .paused ? duration : nil
        )
        notes.append(note)
    }
    
    // MARK: - Computed Properties
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var notesCount: Int {
        notes.count
    }
    
    var canRecord: Bool {
        recordingState == .idle
    }
    
    var canPause: Bool {
        recordingState == .recording
    }
    
    var canResume: Bool {
        recordingState == .paused
    }
    
    var canStop: Bool {
        recordingState == .recording || recordingState == .paused
    }
    
    var isRecordingActive: Bool {
        recordingState == .recording || recordingState == .paused
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Cancel all subscriptions
        cancellables.removeAll()
    }
}