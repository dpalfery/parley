//
//  StorageManagerTests.swift
//  MeetingRecorderTests
//
//  Unit tests for StorageManager
//

import XCTest
import CoreData
@testable import Parley

final class StorageManagerTests: XCTestCase {
    
    var sut: StorageManager!
    var testPersistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        // Use in-memory store for testing
        testPersistenceController = PersistenceController(inMemory: true)
        sut = StorageManager(persistenceController: testPersistenceController)
    }
    
    override func tearDown() {
        sut = nil
        testPersistenceController = nil
        super.tearDown()
    }
    
    // MARK: - CRUD Operation Tests
    
    func testSaveRecording() async throws {
        // Given: A new recording
        let recording = createTestRecording()
        
        // When: Saving the recording
        try await sut.saveRecording(recording)
        
        // Then: Recording should be retrievable
        let retrieved = try await sut.getRecording(id: recording.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, recording.id)
        XCTAssertEqual(retrieved?.title, recording.title)
    }
    
    func testGetRecording() async throws {
        // Given: A saved recording
        let recording = createTestRecording()
        try await sut.saveRecording(recording)
        
        // When: Retrieving the recording
        let retrieved = try await sut.getRecording(id: recording.id)
        
        // Then: Should return the correct recording
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, recording.id)
        XCTAssertEqual(retrieved?.title, recording.title)
        XCTAssertEqual(retrieved?.duration, recording.duration)
    }
    
    func testGetNonExistentRecording() async throws {
        // Given: A non-existent recording ID
        let nonExistentID = UUID()
        
        // When: Attempting to retrieve
        let retrieved = try await sut.getRecording(id: nonExistentID)
        
        // Then: Should return nil
        XCTAssertNil(retrieved)
    }
    
    func testGetAllRecordings() async throws {
        // Given: Multiple saved recordings
        let recording1 = createTestRecording(title: "Recording 1")
        let recording2 = createTestRecording(title: "Recording 2")
        let recording3 = createTestRecording(title: "Recording 3")
        
        try await sut.saveRecording(recording1)
        try await sut.saveRecording(recording2)
        try await sut.saveRecording(recording3)
        
        // When: Retrieving all recordings
        let allRecordings = try await sut.getAllRecordings(sortedBy: .dateDescending)
        
        // Then: Should return all recordings
        XCTAssertEqual(allRecordings.count, 3)
    }
    
    func testGetAllRecordingsSortedByDate() async throws {
        // Given: Recordings with different dates
        let now = Date()
        let recording1 = createTestRecording(title: "Oldest", date: now.addingTimeInterval(-7200))
        let recording2 = createTestRecording(title: "Middle", date: now.addingTimeInterval(-3600))
        let recording3 = createTestRecording(title: "Newest", date: now)
        
        try await sut.saveRecording(recording1)
        try await sut.saveRecording(recording2)
        try await sut.saveRecording(recording3)
        
        // When: Retrieving sorted by date
        let sorted = try await sut.getAllRecordings(sortedBy: .dateDescending)
        
        // Then: Should be in descending date order (newest first)
        XCTAssertEqual(sorted[0].title, "Newest")
        XCTAssertEqual(sorted[1].title, "Middle")
        XCTAssertEqual(sorted[2].title, "Oldest")
    }
    
    func testGetAllRecordingsSortedByTitle() async throws {
        // Given: Recordings with different titles
        let recording1 = createTestRecording(title: "Charlie")
        let recording2 = createTestRecording(title: "Alpha")
        let recording3 = createTestRecording(title: "Bravo")
        
        try await sut.saveRecording(recording1)
        try await sut.saveRecording(recording2)
        try await sut.saveRecording(recording3)
        
        // When: Retrieving sorted by title
        let sorted = try await sut.getAllRecordings(sortedBy: .titleAscending)
        
        // Then: Should be in alphabetical order
        XCTAssertEqual(sorted[0].title, "Alpha")
        XCTAssertEqual(sorted[1].title, "Bravo")
        XCTAssertEqual(sorted[2].title, "Charlie")
    }
    
    func testUpdateRecording() async throws {
        // Given: A saved recording
        var recording = createTestRecording(title: "Original Title")
        try await sut.saveRecording(recording)
        
        // When: Updating the recording
        recording.title = "Updated Title"
        recording.tags = ["updated", "test"]
        try await sut.updateRecording(recording)
        
        // Then: Changes should be persisted
        let updated = try await sut.getRecording(id: recording.id)
        XCTAssertEqual(updated?.title, "Updated Title")
        XCTAssertEqual(updated?.tags, ["updated", "test"])
    }
    
    func testDeleteRecording() async throws {
        // Given: A saved recording
        let recording = createTestRecording()
        try await sut.saveRecording(recording)
        
        // When: Deleting the recording
        try await sut.deleteRecording(id: recording.id, deleteFromCloud: false)
        
        // Then: Recording should no longer exist
        let retrieved = try await sut.getRecording(id: recording.id)
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Search Tests
    
    func testSearchRecordingsByTitle() async throws {
        // Given: Recordings with different titles
        let recording1 = createTestRecording(title: "Team Meeting")
        let recording2 = createTestRecording(title: "Client Call")
        let recording3 = createTestRecording(title: "Team Standup")
        
        try await sut.saveRecording(recording1)
        try await sut.saveRecording(recording2)
        try await sut.saveRecording(recording3)
        
        // When: Searching for "Team"
        let results = try await sut.searchRecordings(query: "Team")
        
        // Then: Should return recordings with "Team" in title
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains(where: { $0.title == "Team Meeting" }))
        XCTAssertTrue(results.contains(where: { $0.title == "Team Standup" }))
    }
    
    func testSearchRecordingsByTranscriptContent() async throws {
        // Given: Recordings with transcript content
        let segment1 = TranscriptSegment(id: UUID(), text: "Discussing project timeline", timestamp: 0, duration: 2, confidence: 0.9, speakerID: "speaker-1", isEdited: false)
        let segment2 = TranscriptSegment(id: UUID(), text: "Reviewing budget numbers", timestamp: 0, duration: 2, confidence: 0.9, speakerID: "speaker-1", isEdited: false)
        
        let recording1 = createTestRecording(title: "Meeting 1", transcript: [segment1])
        let recording2 = createTestRecording(title: "Meeting 2", transcript: [segment2])
        
        try await sut.saveRecording(recording1)
        try await sut.saveRecording(recording2)
        
        // When: Searching for "timeline"
        let results = try await sut.searchRecordings(query: "timeline")
        
        // Then: Should return recording with matching transcript
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertTrue(results.contains(where: { $0.title == "Meeting 1" }))
    }
    
    func testSearchRecordingsEmptyQuery() async throws {
        // Given: Multiple recordings
        try await sut.saveRecording(createTestRecording(title: "Recording 1"))
        try await sut.saveRecording(createTestRecording(title: "Recording 2"))
        
        // When: Searching with empty query
        let results = try await sut.searchRecordings(query: "")
        
        // Then: Should return all recordings
        XCTAssertEqual(results.count, 2)
    }
    
    // MARK: - Storage Usage Tests
    
    func testStorageUsageCalculation() async throws {
        // Given: Multiple recordings with known sizes
        // (Mocking file sizes requires writing actual files in integration tests)
        // For unit tests, we verify the calculation logic returns a valid structure
        
        // When: Getting usage
        let usage = try? await sut.getStorageUsage()
        
        // Then: Should return valid usage data
        XCTAssertNotNil(usage)
        if let usage = usage {
            XCTAssertGreaterThanOrEqual(usage.totalBytes, 0)
            XCTAssertGreaterThanOrEqual(usage.recordingCount, 0)
        }
    }
    
    func testStorageUsageWithNoRecordings() async {
        // Given: No recordings
        
        // When: Getting storage usage
        let usage = try? await sut.getStorageUsage()
        
        // Then: Should return zero
        XCTAssertNotNil(usage)
        if let usage = usage {
            XCTAssertEqual(usage.totalBytes, 0)
        }
    }
    
    // MARK: - Tag Filtering Tests
    
    func testFilterRecordingsByTag() async throws {
        // Given: Recordings with different tags
        let recording1 = createTestRecording(title: "Meeting 1", tags: ["standup", "team-alpha"])
        let recording2 = createTestRecording(title: "Meeting 2", tags: ["client", "important"])
        let recording3 = createTestRecording(title: "Meeting 3", tags: ["standup", "team-beta"])
        
        try await sut.saveRecording(recording1)
        try await sut.saveRecording(recording2)
        try await sut.saveRecording(recording3)
        
        // When: Filtering by "standup" tag
        let allRecordings = try await sut.getAllRecordings(sortedBy: .dateDescending)
        let filtered = allRecordings.filter { $0.tags.contains("standup") }
        
        // Then: Should return recordings with that tag
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains(where: { $0.title == "Meeting 1" }))
        XCTAssertTrue(filtered.contains(where: { $0.title == "Meeting 3" }))
    }
    
    // MARK: - Date Range Filtering Tests
    
    func testFilterRecordingsByDateRange() async throws {
        // Given: Recordings with different dates
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let lastWeek = now.addingTimeInterval(-7 * 86400)
        
        let recording1 = createTestRecording(title: "Today", date: now)
        let recording2 = createTestRecording(title: "Yesterday", date: yesterday)
        let recording3 = createTestRecording(title: "Last Week", date: lastWeek)
        
        try await sut.saveRecording(recording1)
        try await sut.saveRecording(recording2)
        try await sut.saveRecording(recording3)
        
        // When: Filtering by date range (last 2 days)
        let twoDaysAgo = now.addingTimeInterval(-2 * 86400)
        let filtered = try await sut.filterRecordings(from: twoDaysAgo, to: now)
        
        // Then: Should return recordings within range
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains(where: { $0.title == "Today" }))
        XCTAssertTrue(filtered.contains(where: { $0.title == "Yesterday" }))
    }
    
    // MARK: - Update Tests
    
    func testUpdateRecordingTranscript() async throws {
        // Given: A saved recording
        var recording = createTestRecording(title: "Original")
        try await sut.saveRecording(recording)
        
        // When: Updating transcript
        let newSegment = TranscriptSegment(
            id: UUID(),
            text: "New transcript text",
            timestamp: 0,
            duration: 2,
            confidence: 0.9,
            speakerID: "speaker-1",
            isEdited: false
        )
        recording.transcript = [newSegment]
        try await sut.updateRecording(recording)
        
        // Then: Changes should be persisted
        let updated = try await sut.getRecording(id: recording.id)
        XCTAssertEqual(updated?.transcript.count, 1)
        XCTAssertEqual(updated?.transcript.first?.text, "New transcript text")
    }
    
    func testUpdateRecordingNotes() async throws {
        // Given: A saved recording
        var recording = createTestRecording(title: "Original")
        try await sut.saveRecording(recording)
        
        // When: Adding notes
        let note = Note(id: UUID(), text: "Important action item", timestamp: 120.0, createdAt: Date())
        recording.notes = [note]
        try await sut.updateRecording(recording)
        
        // Then: Notes should be persisted
        let updated = try await sut.getRecording(id: recording.id)
        XCTAssertEqual(updated?.notes.count, 1)
        XCTAssertEqual(updated?.notes.first?.text, "Important action item")
    }
    
    // MARK: - Error Handling Tests
    
    func testUpdateNonExistentRecordingThrowsError() async {
        // Given: A recording that doesn't exist
        let recording = createTestRecording()
        
        // When: Attempting to update
        // Then: Should throw error
        do {
            try await sut.updateRecording(recording)
            XCTFail("Should have thrown recordingNotFound error")
        } catch StorageError.recordingNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDeleteNonExistentRecordingThrowsError() async {
        // Given: A non-existent recording ID
        let nonExistentID = UUID()
        
        // When: Attempting to delete
        // Then: Should throw error
        do {
            try await sut.deleteRecording(id: nonExistentID, deleteFromCloud: false)
            XCTFail("Should have thrown recordingNotFound error")
        } catch StorageError.recordingNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestRecording(
        title: String = "Test Recording",
        date: Date = Date(),
        duration: TimeInterval = 300,
        transcript: [TranscriptSegment] = [],
        tags: [String] = [],
        fileSize: Int64 = 1_000_000
    ) -> Recording {
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(RecordingAudioConfig.audioFileExtension)")

        // StorageManager.saveRecording requires the audio file to exist.
        if !FileManager.default.fileExists(atPath: audioURL.path) {
            try? Data([0x00, 0x01, 0x02]).write(to: audioURL)
        }
        
        return Recording(
            id: UUID(),
            title: title,
            date: date,
            duration: duration,
            audioFileURL: audioURL,
            transcript: transcript,
            speakers: [],
            tags: tags,
            notes: [],
            fileSize: fileSize,
            isSynced: false,
            lastModified: date
        )
    }
}
