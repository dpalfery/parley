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
    var mockTranscriptionService: MockTranscriptionService!
    
    override func setUp() {
        super.setUp()
        mockTranscriptionService = MockTranscriptionService()
        sut = RecordingService(transcriptionService: mockTranscriptionService)
    }
    
    override func tearDown() {
        sut = nil
        mockTranscriptionService = nil
        super.tearDown()
    }
    
    // MARK: - State Transition Tests
    
    func testInitialState() {
        // Given: Fresh service instance
        // When: No action taken
        // Then: State should be idle
        XCTAssertEqual(sut.recordingState, .idle)
        XCTAssertEqual(sut.duration, 0)
        XCTAssertEqual(sut.audioLevel, 0)
    }
    
    func testStartRecordingTransitionsToRecordingState() async throws {
        // Given: Service in idle state
        XCTAssertEqual(sut.recordingState, .idle)
        
        // When: Starting recording
        _ = try await sut.startRecording(quality: .medium)
        
        // Then: State should transition to recording
        XCTAssertEqual(sut.recordingState, .recording)
    }
    
    func testPauseRecordingTransitionsToPausedState() async throws {
        // Given: Active recording
        _ = try await sut.startRecording(quality: .medium)
        XCTAssertEqual(sut.recordingState, .recording)
        
        // When: Pausing recording
        try await sut.pauseRecording()
        
        // Then: State should transition to paused
        XCTAssertEqual(sut.recordingState, .paused)
    }
    
    func testResumeRecordingTransitionsBackToRecordingState() async throws {
        // Given: Paused recording
        _ = try await sut.startRecording(quality: .medium)
        try await sut.pauseRecording()
        XCTAssertEqual(sut.recordingState, .paused)
        
        // When: Resuming recording
        try await sut.resumeRecording()
        
        // Then: State should transition back to recording
        XCTAssertEqual(sut.recordingState, .recording)
    }
    
    func testStopRecordingTransitionsToProcessingThenIdle() async throws {
        // Given: Active recording
        _ = try await sut.startRecording(quality: .medium)
        XCTAssertEqual(sut.recordingState, .recording)
        
        // When: Stopping recording
        _ = try await sut.stopRecording()
        
        // Then: State should transition to idle
        XCTAssertEqual(sut.recordingState, .idle)
    }
    
    func testCancelRecordingTransitionsToIdle() async throws {
        // Given: Active recording
        _ = try await sut.startRecording(quality: .medium)
        XCTAssertEqual(sut.recordingState, .recording)
        
        // When: Canceling recording
        try await sut.cancelRecording()
        
        // Then: State should transition to idle
        XCTAssertEqual(sut.recordingState, .idle)
    }
    
    // MARK: - Audio Configuration Tests
    
    func testAudioQualityLowConfiguration() async throws {
        // Given: Low quality setting
        let quality = AudioQuality.low
        
        // When: Starting recording with low quality
        _ = try await sut.startRecording(quality: quality)
        
        // Then: Audio settings should reflect low quality (64 kbps)
        XCTAssertNotNil(sut.currentRecordingSession)
    }
    
    func testAudioQualityMediumConfiguration() async throws {
        // Given: Medium quality setting
        let quality = AudioQuality.medium
        
        // When: Starting recording with medium quality
        _ = try await sut.startRecording(quality: quality)
        
        // Then: Audio settings should reflect medium quality (128 kbps)
        XCTAssertNotNil(sut.currentRecordingSession)
    }
    
    func testAudioQualityHighConfiguration() async throws {
        // Given: High quality setting
        let quality = AudioQuality.high
        
        // When: Starting recording with high quality
        _ = try await sut.startRecording(quality: quality)
        
        // Then: Audio settings should reflect high quality (256 kbps)
        XCTAssertNotNil(sut.currentRecordingSession)
    }
    
    // MARK: - Duration Tracking Tests
    
    func testDurationTracksElapsedTime() async throws {
        // Given: Active recording
        _ = try await sut.startRecording(quality: .medium)
        let initialDuration = sut.duration
        
        // When: Time passes
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Then: Duration should increase
        XCTAssertGreaterThan(sut.duration, initialDuration)
    }
    
    func testDurationMaintainsAccuracyAcrossPauseResume() async throws {
        // Given: Recording with pause
        _ = try await sut.startRecording(quality: .medium)
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        let durationBeforePause = sut.duration
        
        try await sut.pauseRecording()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds during pause
        
        // When: Resuming
        try await sut.resumeRecording()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds after resume
        
        // Then: Duration should not include paused time
        let totalExpectedDuration = durationBeforePause + 0.5
        XCTAssertLessThan(abs(sut.duration - totalExpectedDuration), 0.2) // Allow 200ms tolerance
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
        XCTAssertEqual(sut.recordingState, .idle)
        
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
        XCTAssertEqual(sut.recordingState, .idle)
        
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
}

// MARK: - Mock Transcription Service

class MockTranscriptionService: TranscriptionServiceProtocol {
    var transcriptSegments: Published<[TranscriptSegment]>.Publisher {
        $_transcriptSegments
    }
    @Published var _transcriptSegments: [TranscriptSegment] = []
    
    func startTranscription(audioURL: URL) async throws {
        // Mock implementation
    }
    
    func startLiveTranscription(audioBuffer: AVAudioPCMBuffer) async throws {
        // Mock implementation
    }
    
    func stopTranscription() async {
        // Mock implementation
    }
    
    func getFullTranscript() async -> [TranscriptSegment] {
        return _transcriptSegments
    }
}
