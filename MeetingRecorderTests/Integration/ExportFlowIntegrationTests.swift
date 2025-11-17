//
//  ExportFlowIntegrationTests.swift
//  MeetingRecorderTests
//
//  Integration tests for export and sharing flow
//

import XCTest
@testable import MeetingRecorder

final class ExportFlowIntegrationTests: XCTestCase {
    
    var exportService: ExportService!
    var storageManager: StorageManager!
    var persistenceController: PersistenceController!
    var testRecording: Recording!
    
    override func setUp() {
        super.setUp()
        
        persistenceController = PersistenceController(inMemory: true)
        storageManager = StorageManager(persistenceController: persistenceController)
        exportService = ExportService()
        
        testRecording = createTestRecording()
    }
    
    override func tearDown() {
        testRecording = nil
        exportService = nil
        storageManager = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Export Flow Tests
    
    func testExportPlainTextFlow() async throws {
        // Given: Recording with transcript
        var recording = testRecording!
        recording.transcript = createTestTranscript()
        recording.notes = createTestNotes()
        try await storageManager.saveRecording(recording)
        
        // When: Exporting as plain text
        let textURL = try await exportService.generatePlainText(recording: recording)
        
        // Then: Should create text file
        XCTAssertNotNil(textURL)
        XCTAssertTrue(textURL.pathExtension == "txt")
        
        // Then: File should contain transcript content
        let content = try String(contentsOf: textURL, encoding: .utf8)
        XCTAssertTrue(content.contains("Test Playback Recording"))
        XCTAssertTrue(content.contains("Hello everyone"))
        
        // Then: Should include timestamps
        XCTAssertTrue(content.contains("00:00") || content.contains("0:00"))
        
        // Then: Should include notes
        XCTAssertTrue(content.contains("Action item"))
    }
    
    func testExportMarkdownFlow() async throws {
        // Given: Recording with transcript and speakers
        var recording = testRecording!
        recording.transcript = createTestTranscript()
        recording.speakers = createTestSpeakers()
        recording.notes = createTestNotes()
        try await storageManager.saveRecording(recording)
        
        // When: Exporting as Markdown
        let markdownURL = try await exportService.generateMarkdown(recording: recording)
        
        // Then: Should create markdown file
        XCTAssertNotNil(markdownURL)
        XCTAssertTrue(markdownURL.pathExtension == "md")
        
        // Then: File should contain formatted content
        let content = try String(contentsOf: markdownURL, encoding: .utf8)
        XCTAssertTrue(content.contains("#")) // Markdown headers
        XCTAssertTrue(content.contains("Test Playback Recording"))
        
        // Then: Should include speaker labels
        XCTAssertTrue(content.contains("Alice") || content.contains("speaker"))
        
        // Then: Should include transcript
        XCTAssertTrue(content.contains("Hello everyone"))
        
        // Then: Should include notes section
        XCTAssertTrue(content.contains("Notes") || content.contains("Action"))
    }
    
    func testExportAudioFlow() async throws {
        // Given: Recording with audio file
        try await storageManager.saveRecording(testRecording)
        
        // When: Exporting audio
        let audioURL = try await exportService.generateAudio(recording: testRecording)
        
        // Then: Should return audio file URL
        XCTAssertNotNil(audioURL)
        XCTAssertTrue(audioURL.pathExtension == "m4a")
        XCTAssertEqual(audioURL, testRecording.audioFileURL)
    }
    
    func testExportMultipleFormatsFlow() async throws {
        // Given: Recording ready for export
        var recording = testRecording!
        recording.transcript = createTestTranscript()
        recording.speakers = createTestSpeakers()
        try await storageManager.saveRecording(recording)
        
        // When: Exporting in all formats
        let textURL = try await exportService.generatePlainText(recording: recording)
        let markdownURL = try await exportService.generateMarkdown(recording: recording)
        let audioURL = try await exportService.generateAudio(recording: recording)
        
        // Then: All exports should succeed
        XCTAssertNotNil(textURL)
        XCTAssertNotNil(markdownURL)
        XCTAssertNotNil(audioURL)
        
        // Then: Each should have correct extension
        XCTAssertEqual(textURL.pathExtension, "txt")
        XCTAssertEqual(markdownURL.pathExtension, "md")
        XCTAssertEqual(audioURL.pathExtension, "m4a")
    }
    
    func testExportWithEditedTranscriptFlow() async throws {
        // Given: Recording with edited transcript
        var recording = testRecording!
        var transcript = createTestTranscript()
        transcript[0].text = "Edited: Hello everyone"
        transcript[0].isEdited = true
        recording.transcript = transcript
        try await storageManager.saveRecording(recording)
        
        // When: Exporting
        let textURL = try await exportService.generatePlainText(recording: recording)
        
        // Then: Should include edited content
        let content = try String(contentsOf: textURL, encoding: .utf8)
        XCTAssertTrue(content.contains("Edited: Hello everyone"))
    }
    
    func testExportEmptyTranscriptFlow() async throws {
        // Given: Recording without transcript
        var recording = testRecording!
        recording.transcript = []
        try await storageManager.saveRecording(recording)
        
        // When: Exporting as text
        let textURL = try await exportService.generatePlainText(recording: recording)
        
        // Then: Should still create file with metadata
        XCTAssertNotNil(textURL)
        let content = try String(contentsOf: textURL, encoding: .utf8)
        XCTAssertTrue(content.contains("Test Playback Recording"))
    }
    
    func testExportFileCleanupFlow() async throws {
        // Given: Recording exported to temporary location
        var recording = testRecording!
        recording.transcript = createTestTranscript()
        
        let textURL = try await exportService.generatePlainText(recording: recording)
        
        // When: Cleaning up temporary files
        let fileManager = FileManager.default
        
        // Then: File should exist initially
        XCTAssertTrue(fileManager.fileExists(atPath: textURL.path))
        
        // When: Removing temporary file
        try fileManager.removeItem(at: textURL)
        
        // Then: File should be removed
        XCTAssertFalse(fileManager.fileExists(atPath: textURL.path))
    }
    
    func testExportWithTagsFlow() async throws {
        // Given: Recording with tags
        var recording = testRecording!
        recording.transcript = createTestTranscript()
        recording.tags = ["meeting", "important", "project-alpha"]
        try await storageManager.saveRecording(recording)
        
        // When: Exporting
        let markdownURL = try await exportService.generateMarkdown(recording: recording)
        
        // Then: Should include tags
        let content = try String(contentsOf: markdownURL, encoding: .utf8)
        XCTAssertTrue(content.contains("meeting") || content.contains("Tags"))
    }
    
    // MARK: - Share Flow Tests
    
    func testPrepareForSharingFlow() async throws {
        // Given: Recording to share
        var recording = testRecording!
        recording.transcript = createTestTranscript()
        try await storageManager.saveRecording(recording)
        
        // When: Preparing files for sharing
        let textURL = try await exportService.generatePlainText(recording: recording)
        let audioURL = try await exportService.generateAudio(recording: recording)
        
        // Then: Files should be ready for UIActivityViewController
        XCTAssertNotNil(textURL)
        XCTAssertNotNil(audioURL)
        
        let items: [Any] = [textURL, audioURL]
        XCTAssertEqual(items.count, 2)
    }
    
    // MARK: - Helper Methods
    
    private func createTestRecording() -> Recording {
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        
        return Recording(
            id: UUID(),
            title: "Test Playback Recording",
            date: Date(),
            duration: 300,
            audioFileURL: audioURL,
            transcript: [],
            speakers: [],
            tags: ["test"],
            notes: [],
            fileSize: 2_000_000,
            isSynced: false,
            lastModified: Date()
        )
    }
    
    private func createTestTranscript() -> [TranscriptSegment] {
        return [
            TranscriptSegment(
                id: UUID(),
                text: "Hello everyone, welcome to the meeting.",
                timestamp: 0.0,
                duration: 3.0,
                confidence: 0.95,
                speakerID: "speaker-1",
                isEdited: false
            ),
            TranscriptSegment(
                id: UUID(),
                text: "Thanks for having me. Let's discuss the project.",
                timestamp: 5.0,
                duration: 4.0,
                confidence: 0.92,
                speakerID: "speaker-2",
                isEdited: false
            )
        ]
    }
    
    private func createTestSpeakers() -> [SpeakerProfile] {
        return [
            SpeakerProfile(
                id: "speaker-1",
                displayName: "Alice",
                voiceCharacteristics: Data(),
                createdAt: Date(),
                lastUsed: Date()
            ),
            SpeakerProfile(
                id: "speaker-2",
                displayName: "Bob",
                voiceCharacteristics: Data(),
                createdAt: Date(),
                lastUsed: Date()
            )
        ]
    }
    
    private func createTestNotes() -> [Note] {
        return [
            Note(
                id: UUID(),
                text: "Action item: Review PR #123",
                timestamp: 45.0,
                createdAt: Date()
            )
        ]
    }
}
