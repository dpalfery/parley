//
//  RecordingFlowIntegrationTests.swift
//  MeetingRecorderTests
//
//  Integration tests for end-to-end recording flow
//

import XCTest
import AVFoundation
import Combine
@testable import Parley

final class RecordingFlowIntegrationTests: XCTestCase {
    
    var recordingService: RecordingService!
    var transcriptionService: TranscriptionService!
    var speakerService: SpeakerService!
    var storageManager: StorageManager!
    var cloudSyncService: CloudSyncService!
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        
        // Set up test environment with in-memory storage
        persistenceController = PersistenceController(inMemory: true)
        storageManager = StorageManager(persistenceController: persistenceController)
        transcriptionService = TranscriptionService()
        speakerService = SpeakerService()
        recordingService = RecordingService()
        cloudSyncService = CloudSyncService(storageManager: storageManager)
    }
    
    override func tearDown() {
        recordingService = nil
        transcriptionService = nil
        speakerService = nil
        storageManager = nil
        cloudSyncService = nil
        persistenceController = nil
        super.tearDown()
    }
    
    private func getCurrentState() async -> RecordingState {
        var state: RecordingState = .idle
        let expectation = XCTestExpectation(description: "Get state")
        let cancellable = recordingService.recordingState.sink { value in
            state = value
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        return state
    }

    // MARK: - End-to-End Recording Flow Tests
    
    func testCompleteRecordingFlow() async throws {
        // Given: All services initialized
        let initialState = await getCurrentState()
        XCTAssertEqual(initialState, .idle)
        
        // When: Starting recording
        _ = try await recordingService.startRecording(quality: .medium)
        let recordingState = await getCurrentState()
        XCTAssertEqual(recordingState, .recording)
        
        // Simulate recording for a short duration
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // When: Stopping recording
        let recording = try await recordingService.stopRecording()
        let stoppedState = await getCurrentState()
        XCTAssertEqual(stoppedState, .idle)
        XCTAssertNotNil(recording)
        XCTAssertGreaterThan(recording.duration, 0)
        
        // When: Saving recording
        try await storageManager.saveRecording(recording)
        
        // Then: Recording should be retrievable
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, recording.id)
        
        // When: Syncing to cloud
        try await cloudSyncService.syncRecording(id: recording.id)
        
        // Then: Sync should complete without error
        // (Actual cloud sync would require iCloud setup)
    }
    
    func testRecordingWithPauseResumeFlow() async throws {
        // Given: Recording service ready
        
        // When: Starting recording
        _ = try await recordingService.startRecording(quality: .medium)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        var durationBeforePause: TimeInterval = 0
        let expectation = XCTestExpectation(description: "Get duration")
        let cancellable = recordingService.duration.sink { value in
            durationBeforePause = value
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        
        // When: Pausing
        try await recordingService.pauseRecording()
        let pausedState = await getCurrentState()
        XCTAssertEqual(pausedState, .paused)
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second pause
        
        // When: Resuming
        try await recordingService.resumeRecording()
        let resumedState = await getCurrentState()
        XCTAssertEqual(resumedState, .recording)
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // When: Stopping
        let recording = try await recordingService.stopRecording()
        
        // Then: Duration should reflect active recording time only
        XCTAssertGreaterThan(recording.duration, durationBeforePause)
        XCTAssertLessThan(recording.duration, 3.5) // Should be ~2 seconds, not 3
        
        // When: Saving
        try await storageManager.saveRecording(recording)
        
        // Then: Should be saved successfully
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertNotNil(retrieved)
    }
    
    func testRecordingWithTranscriptionFlow() async throws {
        // Given: Recording and transcription services
        
        // When: Starting recording with transcription
        _ = try await recordingService.startRecording(quality: .medium)
        
        // Simulate audio with transcription
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // When: Stopping recording
        let recording = try await recordingService.stopRecording()
        
        // When: Getting transcript
        let transcript = await transcriptionService.getFullTranscript()
        
        // Then: Recording should have transcript data
        XCTAssertNotNil(recording)
        // Note: Actual transcription requires real audio input
        
        // When: Saving with transcript
        var recordingWithTranscript = recording
        recordingWithTranscript.transcript = transcript
        try await storageManager.saveRecording(recordingWithTranscript)
        
        // Then: Should be retrievable with transcript
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertNotNil(retrieved)
    }
    
    func testRecordingWithSpeakerDetectionFlow() async throws {
        // Given: Recording with speaker detection
        
        // When: Starting recording
        _ = try await recordingService.startRecording(quality: .medium)
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // When: Stopping recording
        let recording = try await recordingService.stopRecording()
        
        // When: Detecting speakers
        let speakers = try await speakerService.detectSpeakers(audioURL: recording.audioFileURL)
        
        // Then: Should have speaker segments
        // Note: Actual speaker detection requires real audio with multiple speakers
        XCTAssertNotNil(speakers)
        
        // When: Saving with speaker data
        let recordingWithSpeakers = recording
        try await storageManager.saveRecording(recordingWithSpeakers)
        
        // Then: Should be saved successfully
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertNotNil(retrieved)
    }
    
    func testMultipleRecordingsFlow() async throws {
        // Given: Multiple recording sessions
        
        // When: Creating first recording
        _ = try await recordingService.startRecording(quality: .medium)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let recording1 = try await recordingService.stopRecording()
        try await storageManager.saveRecording(recording1)
        
        // When: Creating second recording
        _ = try await recordingService.startRecording(quality: .high)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let recording2 = try await recordingService.stopRecording()
        try await storageManager.saveRecording(recording2)
        
        // When: Creating third recording
        _ = try await recordingService.startRecording(quality: .low)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let recording3 = try await recordingService.stopRecording()
        try await storageManager.saveRecording(recording3)
        
        // Then: All recordings should be retrievable
        let allRecordings = try await storageManager.getAllRecordings(sortedBy: .dateDescending)
        XCTAssertEqual(allRecordings.count, 3)
        
        // When: Syncing all
        try await cloudSyncService.syncAll()
        
        // Then: All should be synced
        // (Verification would require checking sync status)
    }
    
    func testRecordingCancellationFlow() async throws {
        // Given: Active recording
        _ = try await recordingService.startRecording(quality: .medium)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // When: Canceling recording
        try await recordingService.cancelRecording()
        
        // Then: Should return to idle without saving
        let cancelledState = await getCurrentState()
        XCTAssertEqual(cancelledState, .idle)
        
        // Then: No recording should be saved
        let allRecordings = try await storageManager.getAllRecordings(sortedBy: .dateDescending)
        XCTAssertEqual(allRecordings.count, 0)
    }
}
