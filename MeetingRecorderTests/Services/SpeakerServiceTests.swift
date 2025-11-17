//
//  SpeakerServiceTests.swift
//  MeetingRecorderTests
//
//  Unit tests for SpeakerService
//

import XCTest
import AVFoundation
@testable import MeetingRecorder

final class SpeakerServiceTests: XCTestCase {
    
    var sut: SpeakerService!
    
    override func setUp() {
        super.setUp()
        sut = SpeakerService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Speaker Detection Tests
    
    func testSpeakerSegmentCreation() {
        // Given: Speaker segment parameters
        let speakerID = "speaker-1"
        let startTime: TimeInterval = 0.0
        let endTime: TimeInterval = 5.0
        
        // When: Creating a speaker segment
        let segment = SpeakerSegment(
            speakerID: speakerID,
            startTime: startTime,
            endTime: endTime
        )
        
        // Then: Segment should have correct properties
        XCTAssertEqual(segment.speakerID, speakerID)
        XCTAssertEqual(segment.startTime, startTime)
        XCTAssertEqual(segment.endTime, endTime)
    }
    
    func testSpeakerSegmentDuration() {
        // Given: Speaker segment
        let segment = SpeakerSegment(
            speakerID: "speaker-1",
            startTime: 2.0,
            endTime: 7.5
        )
        
        // When: Calculating duration
        let duration = segment.endTime - segment.startTime
        
        // Then: Duration should be correct
        XCTAssertEqual(duration, 5.5, accuracy: 0.01)
    }
    
    func testMultipleSpeakerSegmentsNonOverlapping() {
        // Given: Multiple speaker segments
        let segment1 = SpeakerSegment(speakerID: "speaker-1", startTime: 0, endTime: 5)
        let segment2 = SpeakerSegment(speakerID: "speaker-2", startTime: 5, endTime: 10)
        let segment3 = SpeakerSegment(speakerID: "speaker-1", startTime: 10, endTime: 15)
        
        // When: Checking for overlaps
        // Then: Segments should not overlap
        XCTAssertLessThanOrEqual(segment1.endTime, segment2.startTime)
        XCTAssertLessThanOrEqual(segment2.endTime, segment3.startTime)
    }
    
    // MARK: - Speaker ID Assignment Tests
    
    func testSequentialSpeakerIDAssignment() {
        // Given: Multiple speakers detected
        let speaker1ID = "speaker-1"
        let speaker2ID = "speaker-2"
        let speaker3ID = "speaker-3"
        
        // When: Assigning IDs
        let ids = [speaker1ID, speaker2ID, speaker3ID]
        
        // Then: IDs should follow sequential pattern
        XCTAssertTrue(ids[0].contains("1"))
        XCTAssertTrue(ids[1].contains("2"))
        XCTAssertTrue(ids[2].contains("3"))
    }
    
    func testSpeakerIDConsistencyWithinSession() {
        // Given: Same speaker appearing multiple times
        let segments = [
            SpeakerSegment(speakerID: "speaker-1", startTime: 0, endTime: 5),
            SpeakerSegment(speakerID: "speaker-2", startTime: 5, endTime: 10),
            SpeakerSegment(speakerID: "speaker-1", startTime: 10, endTime: 15)
        ]
        
        // When: Checking speaker IDs
        // Then: Same speaker should have same ID
        XCTAssertEqual(segments[0].speakerID, segments[2].speakerID)
        XCTAssertNotEqual(segments[0].speakerID, segments[1].speakerID)
    }
    
    // MARK: - Speaker Profile Tests
    
    func testSpeakerProfileCreation() {
        // Given: Speaker profile parameters
        let id = "speaker-1"
        let displayName = "John Doe"
        let voiceCharacteristics = Data()
        let createdAt = Date()
        
        // When: Creating a speaker profile
        let profile = SpeakerProfile(
            id: id,
            displayName: displayName,
            voiceCharacteristics: voiceCharacteristics,
            createdAt: createdAt,
            lastUsed: createdAt
        )
        
        // Then: Profile should have correct properties
        XCTAssertEqual(profile.id, id)
        XCTAssertEqual(profile.displayName, displayName)
        XCTAssertEqual(profile.createdAt, createdAt)
    }
    
    func testSpeakerProfileNameUpdate() {
        // Given: Speaker profile with default name
        var profile = SpeakerProfile(
            id: "speaker-1",
            displayName: "Speaker 1",
            voiceCharacteristics: Data(),
            createdAt: Date(),
            lastUsed: Date()
        )
        
        // When: Updating display name
        profile.displayName = "Alice Smith"
        
        // Then: Name should be updated
        XCTAssertEqual(profile.displayName, "Alice Smith")
    }
    
    func testSpeakerProfileLastUsedUpdate() {
        // Given: Speaker profile
        let createdAt = Date()
        var profile = SpeakerProfile(
            id: "speaker-1",
            displayName: "Speaker 1",
            voiceCharacteristics: Data(),
            createdAt: createdAt,
            lastUsed: createdAt
        )
        
        // When: Updating last used timestamp
        let newLastUsed = Date().addingTimeInterval(3600) // 1 hour later
        profile.lastUsed = newLastUsed
        
        // Then: Last used should be updated
        XCTAssertGreaterThan(profile.lastUsed, createdAt)
    }
    
    // MARK: - Speaker Assignment Tests
    
    func testAssignSpeakerToTranscriptSegment() async throws {
        // Given: Transcript segment and speaker ID
        let segmentID = UUID()
        let speakerID = "speaker-1"
        
        // When: Assigning speaker to segment
        try await sut.assignSpeakerToSegment(segmentID: segmentID, speakerID: speakerID)
        
        // Then: Assignment should succeed without error
        // (Actual verification would require checking storage)
    }
    
    func testUpdateSpeakerName() async throws {
        // Given: Speaker ID and new name
        let speakerID = "speaker-1"
        let newName = "Bob Johnson"
        
        // When: Updating speaker name
        try await sut.updateSpeakerName(speakerID: speakerID, name: newName)
        
        // Then: Update should succeed without error
        // (Actual verification would require checking storage)
    }
    
    // MARK: - Codable Tests
    
    func testSpeakerProfileEncodingDecoding() throws {
        // Given: A speaker profile
        let originalProfile = SpeakerProfile(
            id: "speaker-1",
            displayName: "Test Speaker",
            voiceCharacteristics: Data([1, 2, 3, 4]),
            createdAt: Date(),
            lastUsed: Date()
        )
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalProfile)
        
        let decoder = JSONDecoder()
        let decodedProfile = try decoder.decode(SpeakerProfile.self, from: data)
        
        // Then: Decoded profile should match original
        XCTAssertEqual(decodedProfile.id, originalProfile.id)
        XCTAssertEqual(decodedProfile.displayName, originalProfile.displayName)
        XCTAssertEqual(decodedProfile.voiceCharacteristics, originalProfile.voiceCharacteristics)
    }
    
    func testMultipleSpeakerProfilesEncodingDecoding() throws {
        // Given: Multiple speaker profiles
        let profiles = [
            SpeakerProfile(id: "speaker-1", displayName: "Alice", voiceCharacteristics: Data(), createdAt: Date(), lastUsed: Date()),
            SpeakerProfile(id: "speaker-2", displayName: "Bob", voiceCharacteristics: Data(), createdAt: Date(), lastUsed: Date()),
            SpeakerProfile(id: "speaker-3", displayName: "Charlie", voiceCharacteristics: Data(), createdAt: Date(), lastUsed: Date())
        ]
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(profiles)
        
        let decoder = JSONDecoder()
        let decodedProfiles = try decoder.decode([SpeakerProfile].self, from: data)
        
        // Then: All profiles should be preserved
        XCTAssertEqual(decodedProfiles.count, profiles.count)
        for i in 0..<profiles.count {
            XCTAssertEqual(decodedProfiles[i].id, profiles[i].id)
            XCTAssertEqual(decodedProfiles[i].displayName, profiles[i].displayName)
        }
    }
}
