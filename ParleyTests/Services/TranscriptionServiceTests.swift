//
//  TranscriptionServiceTests.swift
//  MeetingRecorderTests
//
//  Unit tests for TranscriptionService
//

import XCTest
import AVFoundation
import Speech
@testable import Parley

final class TranscriptionServiceTests: XCTestCase {
    
    var sut: TranscriptionService!
    
    override func setUp() {
        super.setUp()
        sut = TranscriptionService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Segment Generation Tests

    func testLiveTranscriptionAccumulatesAcrossFinalBlocks() async {
        await MainActor.run {
            sut._testIngest(
                wordSegments: [
                    (timestamp: 0.0, duration: 0.2, text: "Hello", confidence: 0.9),
                    (timestamp: 0.3, duration: 0.2, text: "world", confidence: 0.9)
                ],
                isFinal: true
            )

            sut._testIngest(
                wordSegments: [
                    (timestamp: 0.0, duration: 0.2, text: "Next", confidence: 0.9),
                    (timestamp: 0.3, duration: 0.2, text: "block", confidence: 0.9)
                ],
                isFinal: true
            )
        }

        let transcript = await sut.getFullTranscript()
        XCTAssertEqual(transcript.count, 2)
        XCTAssertEqual(transcript[0].text, "Hello world")
        XCTAssertEqual(transcript[1].text, "Next block")
        XCTAssertGreaterThan(transcript[1].timestamp, transcript[0].timestamp)
    }
    
    func testTranscriptSegmentCreation() {
        // Given: Segment parameters
        let text = "Hello world"
        let timestamp: TimeInterval = 5.0
        let duration: TimeInterval = 2.0
        let confidence: Float = 0.95
        let speakerID = "speaker-1"
        
        // When: Creating a transcript segment
        let segment = TranscriptSegment(
            id: UUID(),
            text: text,
            timestamp: timestamp,
            duration: duration,
            confidence: confidence,
            speakerID: speakerID,
            isEdited: false
        )
        
        // Then: Segment should have correct properties
        XCTAssertEqual(segment.text, text)
        XCTAssertEqual(segment.timestamp, timestamp)
        XCTAssertEqual(segment.duration, duration)
        XCTAssertEqual(segment.confidence, confidence)
        XCTAssertEqual(segment.speakerID, speakerID)
        XCTAssertFalse(segment.isEdited)
    }
    
    func testLowConfidenceSegmentIdentification() {
        // Given: Low confidence segment
        let lowConfidenceSegment = TranscriptSegment(
            id: UUID(),
            text: "Unclear audio",
            timestamp: 0,
            duration: 1,
            confidence: 0.3,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        // When: Checking confidence
        // Then: Should be marked as low confidence (< 0.5)
        XCTAssertLessThan(lowConfidenceSegment.confidence, 0.5)
    }
    
    func testHighConfidenceSegmentIdentification() {
        // Given: High confidence segment
        let highConfidenceSegment = TranscriptSegment(
            id: UUID(),
            text: "Clear audio",
            timestamp: 0,
            duration: 1,
            confidence: 0.95,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        // When: Checking confidence
        // Then: Should be marked as high confidence (>= 0.5)
        XCTAssertGreaterThanOrEqual(highConfidenceSegment.confidence, 0.5)
    }
    
    // MARK: - Timestamp Accuracy Tests
    
    func testTimestampSequencing() {
        // Given: Multiple segments
        let segment1 = TranscriptSegment(
            id: UUID(),
            text: "First",
            timestamp: 0.0,
            duration: 1.0,
            confidence: 0.9,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        let segment2 = TranscriptSegment(
            id: UUID(),
            text: "Second",
            timestamp: 1.5,
            duration: 1.0,
            confidence: 0.9,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        let segment3 = TranscriptSegment(
            id: UUID(),
            text: "Third",
            timestamp: 3.0,
            duration: 1.0,
            confidence: 0.9,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        // When: Ordering segments
        let segments = [segment1, segment2, segment3]
        
        // Then: Timestamps should be in ascending order
        for i in 0..<segments.count - 1 {
            XCTAssertLessThan(segments[i].timestamp, segments[i + 1].timestamp)
        }
    }
    
    func testTimestampCalculationFromRecordingStart() {
        // Given: Recording start time and segment time
        let recordingStartTime: TimeInterval = 100.0
        let segmentAbsoluteTime: TimeInterval = 105.5
        
        // When: Calculating relative timestamp
        let relativeTimestamp = segmentAbsoluteTime - recordingStartTime
        
        // Then: Relative timestamp should be accurate
        XCTAssertEqual(relativeTimestamp, 5.5, accuracy: 0.01)
    }
    
    // MARK: - Segment Metadata Tests
    
    func testSegmentWithPunctuationAndCapitalization() {
        // Given: Transcribed text with punctuation
        let segment = TranscriptSegment(
            id: UUID(),
            text: "Hello, how are you?",
            timestamp: 0,
            duration: 2,
            confidence: 0.9,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        // When: Checking text
        // Then: Should have proper punctuation and capitalization
        XCTAssertTrue(segment.text.contains(","))
        XCTAssertTrue(segment.text.contains("?"))
        XCTAssertTrue(segment.text.first?.isUppercase ?? false)
    }
    
    func testSegmentEditTracking() {
        // Given: Original segment
        let segment = TranscriptSegment(
            id: UUID(),
            text: "Original text",
            timestamp: 0,
            duration: 1,
            confidence: 0.9,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        // When: Editing text (simulating edit by creating new segment since struct is immutable)
        let editedSegment = TranscriptSegment(
            id: segment.id,
            text: "Edited text",
            timestamp: segment.timestamp,
            duration: segment.duration,
            confidence: segment.confidence,
            speakerID: segment.speakerID,
            isEdited: true
        )
        
        // Then: Segment should be marked as edited
        XCTAssertTrue(editedSegment.isEdited)
        XCTAssertEqual(editedSegment.text, "Edited text")
    }
    
    // MARK: - Codable Tests
    
    func testTranscriptSegmentEncodingDecoding() throws {
        // Given: A transcript segment
        let originalSegment = TranscriptSegment(
            id: UUID(),
            text: "Test segment",
            timestamp: 5.5,
            duration: 2.0,
            confidence: 0.85,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSegment)
        
        let decoder = JSONDecoder()
        let decodedSegment = try decoder.decode(TranscriptSegment.self, from: data)
        
        // Then: Decoded segment should match original
        XCTAssertEqual(decodedSegment.id, originalSegment.id)
        XCTAssertEqual(decodedSegment.text, originalSegment.text)
        XCTAssertEqual(decodedSegment.timestamp, originalSegment.timestamp)
        XCTAssertEqual(decodedSegment.duration, originalSegment.duration)
        XCTAssertEqual(decodedSegment.confidence, originalSegment.confidence)
        XCTAssertEqual(decodedSegment.speakerID, originalSegment.speakerID)
        XCTAssertEqual(decodedSegment.isEdited, originalSegment.isEdited)
    }
    
    func testMultipleSegmentsEncodingDecoding() throws {
        // Given: Multiple segments
        let segments = [
            TranscriptSegment(id: UUID(), text: "First", timestamp: 0, duration: 1, confidence: 0.9, speakerID: "speaker-1", isEdited: false),
            TranscriptSegment(id: UUID(), text: "Second", timestamp: 1.5, duration: 1, confidence: 0.85, speakerID: "speaker-2", isEdited: false),
            TranscriptSegment(id: UUID(), text: "Third", timestamp: 3, duration: 1, confidence: 0.95, speakerID: "speaker-1", isEdited: true)
        ]
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(segments)
        
        let decoder = JSONDecoder()
        let decodedSegments = try decoder.decode([TranscriptSegment].self, from: data)
        
        // Then: All segments should be preserved
        XCTAssertEqual(decodedSegments.count, segments.count)
        for i in 0..<segments.count {
            XCTAssertEqual(decodedSegments[i].text, segments[i].text)
            XCTAssertEqual(decodedSegments[i].timestamp, segments[i].timestamp)
        }
    }
    
    // MARK: - Segment Helper Methods Tests
    
    func testSegmentEndTime() {
        // Given: A transcript segment
        let segment = TranscriptSegment(
            id: UUID(),
            text: "Test",
            timestamp: 5.0,
            duration: 2.5,
            confidence: 0.9,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        // Then: End time should be correct
        let endTime = segment.timestamp + segment.duration
        XCTAssertEqual(endTime, 7.5)
    }
    
    func testSegmentWithUpdatedText() {
        // Given: A transcript segment
        let segment = TranscriptSegment(
            id: UUID(),
            text: "Original text",
            timestamp: 0,
            duration: 1,
            confidence: 0.9,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        // When: Updating text
        let updated = TranscriptSegment(
            id: segment.id,
            text: "Edited text",
            timestamp: segment.timestamp,
            duration: segment.duration,
            confidence: segment.confidence,
            speakerID: segment.speakerID,
            isEdited: true
        )
        
        // Then: New segment should have updated text
        XCTAssertEqual(updated.text, "Edited text")
        XCTAssertTrue(updated.isEdited)
    }
    
    func testSegmentWithUpdatedSpeaker() {
        // Given: A transcript segment
        let segment = TranscriptSegment(
            id: UUID(),
            text: "Test text",
            timestamp: 0,
            duration: 1,
            confidence: 0.9,
            speakerID: "speaker-1",
            isEdited: false
        )
        
        // When: Creating updated segment with new speaker
        let updated = segment.withUpdatedSpeaker("speaker-2")
        
        // Then: Should have new speaker and be marked as edited
        XCTAssertEqual(updated.id, segment.id)
        XCTAssertEqual(updated.text, segment.text)
        XCTAssertEqual(updated.speakerID, "speaker-2")
        XCTAssertTrue(updated.isEdited)
    }
    
    func testSegmentFormattedTimestamp() {
        // Given: Segments with different timestamps
        let segment1 = TranscriptSegment(id: UUID(), text: "Test", timestamp: 65.0, duration: 1, confidence: 0.9, speakerID: "speaker-1", isEdited: false)
        let segment2 = TranscriptSegment(id: UUID(), text: "Test", timestamp: 125.5, duration: 1, confidence: 0.9, speakerID: "speaker-1", isEdited: false)
        
        // When: Getting formatted timestamps
        let formatted1 = segment1.formattedTimestamp
        let formatted2 = segment2.formattedTimestamp
        
        // Then: Should be properly formatted (MM:SS)
        XCTAssertEqual(formatted1, "01:05")
        XCTAssertEqual(formatted2, "02:05")
    }
    
    // MARK: - Confidence Threshold Tests
    
    func testConfidenceThresholdBoundary() {
        // Given: Segments at confidence boundary
        let lowConfidence = TranscriptSegment(id: UUID(), text: "Low", timestamp: 0, duration: 1, confidence: 0.49, speakerID: "speaker-1", isEdited: false)
        let highConfidence = TranscriptSegment(id: UUID(), text: "High", timestamp: 0, duration: 1, confidence: 0.50, speakerID: "speaker-1", isEdited: false)
        
        // When: Checking confidence levels
        // Then: Should correctly identify low vs high confidence
        XCTAssertTrue(lowConfidence.isLowConfidence)
        XCTAssertFalse(highConfidence.isLowConfidence)
    }
}
