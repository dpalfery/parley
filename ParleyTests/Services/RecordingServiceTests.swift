//
//  RecordingServiceTests.swift
//  MeetingRecorderTests
//
//  Unit tests for RecordingService
//

import XCTest
import AVFoundation
@testable import MeetingRecorder

final class RecordingServiceTests: XCTestCase {
    
    var sut: RecordingService!
    
    override func setUp() {
        super.setUp()
        sut = RecordingService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentState() -> RecordingState {
        var state: RecordingState = .idle
        let expectation = XCTestExpectation(description: "Get state")
        let cancellable = sut.recordingState.sink { value in
            state = value
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
        return state
    }
    
    private func getCurrentDuration() -> TimeInterval {
        var duration: TimeInterval = 0
        let expectation = XCTestExpectation(description: "Get duration")
        let cancellable = sut.duration.sink { value in
            duration = value
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
        return duration
    }
    
    private func getCurrentAudioLevel() -> Float {
        var level: Float = 0
        let expectation = XCTestExpectation(description: "Get audio level")
        let cancellable = sut.audioLevel.sink { value in
            level = value
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
        return level
    }
    
    // MARK: - State Transition Tests
    
    func testInitialState() {
        // Given: Fresh service instance
        // When: No action taken
        // Then: State should be idle
        XCTAssertEqual(getCurrentState(), .idle)
        XCTAssertEqual(getCurrentDuration(), 0)
        XCTAssertEqual(getCurrentAudioLevel(), 0)
    }
    
    func testStartRecordingTransitionsToRecordingState() async throws {
        // Given: Service in idle state
        XCTAssertEqual(getCurrentState(), .idle)
        
        // When: Starting recording
        _ = try await sut.startRecording(quality: .medium)
        
        // Then: State should transition to recording
        XCTAssertEqual(getCurrentState(), .recording)
        
        // Cleanup
        try await sut.cancelRecording()
    }
    
    func testPauseRecordingTransitionsToPausedState() async throws {
        // Given: Active recording
        _ = try await sut.startRecording(quality: .medium)
        XCTAssertEqual(getCurrentState(), .recording)
        
        // When: Pausing recording
        try await sut.pauseRecording()
        
        // Then: State should transition to paused
        XCTAssertEqual(getCurrentState(), .paused)
        
        // Cleanup
        try await sut.cancelRecording()
    }
    
    func testResumeRecordingTransitionsBackToRecordingState() async throws {
        // Given: Paused recording
        _ = try await sut.startRecording(quality: .medium)
        try await sut.pauseRecording()
        XCTAssertEqual(getCurrentState(), .paused)
        
        // When: Resuming recording
        try await sut.resumeRecording()
        
        // Then: State should transition back to recording
        XCTAssertEqual(getCurrentState(), .recording)
        
        // Cleanup
        try await sut.cancelRecording()
    }
    
    func testStopRecordingTransitionsToProcessingThenIdle() async throws {
        // Given: Active recording
        _ = try await sut.startRecording(quality: .medium)
        XCTAssertEqual(getCurrentState(), .recording)
        
        // When: Stopping recording
        _ = try await sut.stopRecording()
        
        // Then: State should transition to idle
        XCTAssertEqual(getCurrentState(), .idle)
    }
    
    func testCancelRecordingTransitionsToIdle() async throws {
        // Given: Active recording
        _ = try await sut.startRecording(quality: .medium)
        XCTAssertEqual(getCurrentState(), .recording)
        
        // When: Canceling recording
        try await sut.cancelRecording()
        
        // Then: State should transition to idle
        XCTAssertEqual(getCurrentState(), .idle)
    }
    
    // MARK: - Audio Configuration Tests
    
    func testAudioQualityLowConfiguration() async throws {
        // Given: Low quality setting
        let quality = AudioQuality.low
        
        // When: Starting recording with low quality
        let session = try await sut.startRecording(quality: quality)
        
        // Then: Session should be created with correct quality
        XCTAssertEqual(session.quality, quality)
        XCTAssertEqual(quality.bitRate, 64000)
        
        // Cleanup
        try await sut.cancelRecording()
    }
    
    func testAudioQualityMediumConfiguration() async throws {
        // Given: Medium quality setting
        let quality = AudioQuality.medium
        
        // When: Starting recording with medium quality
        let session = try await sut.startRecording(quality: quality)
        
        // Then: Session should be created with correct quality
        XCTAssertEqual(session.quality, quality)
        XCTAssertEqual(quality.bitRate, 128000)
        
        // Cleanup
        try await sut.cancelRecording()
    }
    
    func testAudioQualityHighConfiguration() async throws {
        // Given: High quality setting
        let quality = AudioQuality.high
        
        // When: Starting recording with high quality
        let session = try await sut.startRecording(quality: quality)
        
        // Then: Session should be created with correct quality
        XCTAssertEqual(session.quality, quality)
        XCTAssertEqual(quality.bitRate, 256000)
        
        // Cleanup
        try await sut.cancelRecording()
    }
    
    // MARK: - Duration Tracking Tests
    
    func testDurationTracksElapsedTime() async throws {
        // Given: Active recording
        _ = try await sut.startRecording(quality: .medium)
        let initialDuration = getCurrentDuration()
        
        // When: Time passes
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: Duration should increase
        XCTAssertGreaterThan(getCurrentDuration(), initialDuration)
        
        // Cleanup
        try await sut.cancelRecording()
    }
    
    func testDurationMaintainsAccuracyAcrossPauseResume() async throws {
        // Given: Recording with pause
        _ = try await sut.startRecording(quality: .medium)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        let durationBeforePause = getCurrentDuration()
        
        try await sut.pauseRecording()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds during pause
        
        // When: Resuming
        try await sut.resumeRecording()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds after resume
        
        // Then: Duration should not include paused time
        let totalExpectedDuration = durationBeforePause + 0.5
        XCTAssertLessThan(abs(getCurrentDuration() - totalExpectedDuration), 0.2) // Allow 200ms tolerance
        
        // Cleanup
        try await sut.cancelRecording()
    }
    
    // MARK: - Error Handling Tests
    
    func testStartRecordingWhileRecordingThrowsError() async {
        // Given: Active recording
        do {
            _ = try await sut.startRecording(quality: .medium)
            
            // When: Attempting to start another recording
            // Then: Should throw error
            do {
                _ = try await sut.startRecording(quality: .medium)
                XCTFail("Should have thrown recordingInProgress error")
            } catch RecordingError.recordingInProgress {
                // Expected error
            }
        } catch {
            XCTFail("Initial recording should not fail: \(error)")
        }
    }
    
    func testPauseWithoutActiveRecordingThrowsError() async {
        // Given: No active recording
        XCTAssertEqual(getCurrentState(), .idle)
        
        // When: Attempting to pause
        // Then: Should throw error
        do {
            try await sut.pauseRecording()
            XCTFail("Should have thrown noActiveRecording error")
        } catch RecordingError.noActiveRecording {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testResumeWithoutPausedRecordingThrowsError() async {
        // Given: No paused recording
        XCTAssertEqual(getCurrentState(), .idle)
        
        // When: Attempting to resume
        // Then: Should throw error
        do {
            try await sut.resumeRecording()
            XCTFail("Should have thrown noActiveRecording error")
        } catch RecordingError.noActiveRecording {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testStopWithoutActiveRecordingThrowsError() async {
        // Given: No active recording
        XCTAssertEqual(getCurrentState(), .idle)
        
        // When: Attempting to stop
        // Then: Should throw error
        do {
            _ = try await sut.stopRecording()
            XCTFail("Should have thrown noActiveRecording error")
        } catch RecordingError.noActiveRecording {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCancelWithoutActiveRecordingThrowsError() async {
        // Given: No active recording
        XCTAssertEqual(getCurrentState(), .idle)
        
        // When: Attempting to cancel
        // Then: Should throw error
        do {
            try await sut.cancelRecording()
            XCTFail("Should have thrown noActiveRecording error")
        } catch RecordingError.noActiveRecording {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRecordingStatePublisher() async throws {
        // Given: Service in idle state
        var stateChanges: [RecordingState] = []
        let cancellable = sut.recordingState.sink { state in
            stateChanges.append(state)
        }
        
        // When: Starting and stopping recording
        _ = try await sut.startRecording(quality: .medium)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        _ = try await sut.stopRecording()
        
        // Then: Should have captured state transitions
        XCTAssertTrue(stateChanges.contains(.recording))
        
        cancellable.cancel()
    }
    
    func testAudioLevelPublisher() async throws {
        // Given: Active recording
        var audioLevels: [Float] = []
        let cancellable = sut.audioLevel.sink { level in
            audioLevels.append(level)
        }
        
        // When: Recording for a short time
        _ = try await sut.startRecording(quality: .medium)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        try await sut.cancelRecording()
        
        // Then: Should have captured audio levels
        XCTAssertGreaterThan(audioLevels.count, 0)
        
        cancellable.cancel()
    }
}


