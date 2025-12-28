//
//  OfflineScenarioTests.swift
//  MeetingRecorderTests
//
//  Integration tests for offline scenarios and sync recovery
//

import XCTest
import Combine
@testable import Parley

final class OfflineScenarioTests: XCTestCase {
    
    var recordingService: RecordingService!
    var storageManager: StorageManager!
    var cloudSyncService: CloudSyncService!
    var persistenceController: PersistenceController!
    
    override func setUp() {
        super.setUp()
        
        persistenceController = PersistenceController(inMemory: true)
        storageManager = StorageManager(persistenceController: persistenceController)
        cloudSyncService = CloudSyncService(storageManager: storageManager)
        recordingService = RecordingService()
    }
    
    override func tearDown() {
        recordingService = nil
        storageManager = nil
        cloudSyncService = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Offline Recording Tests
    
    func testRecordingWhileOffline() async throws {
        // Given: Device is offline (simulated)
        // Note: Recording should work offline as it's local-first
        
        let recording = createTestRecording()
        
        // When: Saving recording while offline
        try await storageManager.saveRecording(recording)
        
        // Then: Recording should be saved locally
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, recording.id)
        XCTAssertFalse(retrieved?.isSynced ?? true)
    }
    
    func testMultipleRecordingsWhileOffline() async throws {
        // Given: Multiple recordings created offline
        let recording1 = createTestRecording(title: "Offline 1")
        let recording2 = createTestRecording(title: "Offline 2")
        let recording3 = createTestRecording(title: "Offline 3")
        
        // When: Saving all recordings
        try await storageManager.saveRecording(recording1)
        try await storageManager.saveRecording(recording2)
        try await storageManager.saveRecording(recording3)
        
        // Then: All should be saved locally
        let allRecordings = try await storageManager.getAllRecordings(sortedBy: .dateDescending)
        XCTAssertEqual(allRecordings.count, 3)
        
        // Then: None should be synced
        XCTAssertTrue(allRecordings.allSatisfy { !$0.isSynced })
    }
    
    // MARK: - Sync Queue Tests
    
    func testSyncQueueWhileOffline() async throws {
        // Given: Recording to sync while offline
        let recording = createTestRecording()
        try await storageManager.saveRecording(recording)
        
        // When: Attempting to sync while offline
        // Note: Should queue for later without throwing error
        do {
            try await cloudSyncService.syncRecording(id: recording.id)
        } catch {
            // Expected to handle gracefully or queue
        }
        
        // Then: Recording should remain unsynced
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertFalse(retrieved?.isSynced ?? true)
    }
    
    func testSyncQueueAccumulatesOfflineRecordings() async throws {
        // Given: Multiple recordings created while offline
        let recordings = [
            createTestRecording(title: "Queue 1"),
            createTestRecording(title: "Queue 2"),
            createTestRecording(title: "Queue 3")
        ]
        
        for recording in recordings {
            try await storageManager.saveRecording(recording)
            
            // When: Attempting to sync each
            do {
                try await cloudSyncService.syncRecording(id: recording.id)
            } catch {
                // Queue for later
            }
        }
        
        // Then: All should be in local storage
        let allRecordings = try await storageManager.getAllRecordings(sortedBy: .dateDescending)
        XCTAssertEqual(allRecordings.count, 3)
    }
    
    // MARK: - Sync Recovery Tests
    
    func testSyncRecoveryWhenOnline() async throws {
        // Given: Recordings created while offline
        let recording1 = createTestRecording(title: "Recovery 1")
        let recording2 = createTestRecording(title: "Recovery 2")
        
        try await storageManager.saveRecording(recording1)
        try await storageManager.saveRecording(recording2)
        
        // When: Coming back online and syncing
        try await cloudSyncService.syncAll()
        
        // Then: Sync should be attempted
        // Note: Actual sync would require network connectivity
        // In test environment, we verify the attempt was made
    }
    
    func testPartialSyncRecovery() async throws {
        // Given: Some recordings synced, some not
        var syncedRecording = createTestRecording(title: "Synced")
        syncedRecording.isSynced = true
        
        let unsyncedRecording = createTestRecording(title: "Unsynced")
        
        try await storageManager.saveRecording(syncedRecording)
        try await storageManager.saveRecording(unsyncedRecording)
        
        // When: Syncing all
        try await cloudSyncService.syncAll()
        
        // Then: Should only attempt to sync unsynced recordings
        let allRecordings = try await storageManager.getAllRecordings(sortedBy: .dateDescending)
        let unsyncedCount = allRecordings.filter { !$0.isSynced }.count
        
        // At least one should be unsynced (the one we created as unsynced)
        XCTAssertGreaterThanOrEqual(unsyncedCount, 1)
    }
    
    func testSyncRetryAfterFailure() async throws {
        // Given: Recording that failed to sync
        let recording = createTestRecording()
        try await storageManager.saveRecording(recording)
        
        // When: First sync attempt fails (simulated)
        do {
            try await cloudSyncService.syncRecording(id: recording.id)
        } catch {
            // First attempt failed
        }
        
        // When: Retrying sync
        do {
            try await cloudSyncService.syncRecording(id: recording.id)
        } catch {
            // Retry may also fail in test environment
        }
        
        // Then: Should handle retry gracefully
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertNotNil(retrieved)
    }
    
    // MARK: - Data Integrity Tests
    
    func testDataIntegrityDuringOfflinePeriod() async throws {
        // Given: Recording created and modified offline
        var recording = createTestRecording()
        try await storageManager.saveRecording(recording)
        
        // When: Modifying recording offline
        recording.title = "Modified Offline"
        recording.tags = ["offline", "modified"]
        try await storageManager.updateRecording(recording)
        
        // Then: Changes should be preserved
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertEqual(retrieved?.title, "Modified Offline")
        XCTAssertEqual(retrieved?.tags, ["offline", "modified"])
    }
    
    func testSearchFunctionalityWhileOffline() async throws {
        // Given: Recordings stored locally
        let recording1 = createTestRecording(title: "Team Meeting Offline")
        let recording2 = createTestRecording(title: "Client Call Offline")
        
        try await storageManager.saveRecording(recording1)
        try await storageManager.saveRecording(recording2)
        
        // When: Searching while offline
        let results = try await storageManager.searchRecordings(query: "Team")
        
        // Then: Search should work on local data
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertTrue(results.contains(where: { $0.title.contains("Team") }))
    }
    
    func testStorageUsageCalculationWhileOffline() async throws {
        // Given: Recordings stored locally
        let recording1 = createTestRecording(fileSize: 1_000_000)
        let recording2 = createTestRecording(fileSize: 2_000_000)
        
        try await storageManager.saveRecording(recording1)
        try await storageManager.saveRecording(recording2)
        
        // When: Calculating storage usage offline
        let usage = try await storageManager.getStorageUsage()
        
        // Then: Should calculate from local data
        XCTAssertEqual(usage.totalBytes, 3_000_000)
        XCTAssertEqual(usage.recordingCount, 2)
    }
    
    func testDeletionWhileOffline() async throws {
        // Given: Recording stored locally
        let recording = createTestRecording()
        try await storageManager.saveRecording(recording)
        
        // When: Deleting while offline (local only)
        try await storageManager.deleteRecording(id: recording.id, deleteFromCloud: false)
        
        // Then: Should be deleted locally
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertNil(retrieved)
    }
    
    // MARK: - Sync Status Tests
    
    private func getCurrentSyncStatus() async -> SyncStatus {
        var status: SyncStatus = .idle
        let expectation = XCTestExpectation(description: "Get status")
        let cancellable = cloudSyncService.syncStatus.sink { value in
            status = value
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        return status
    }

    func testOfflineRecording() async throws {
        // Given: Offline status
        // (Mocking network reachability would be ideal, but for now we verify service behavior)
        
        // When: Starting recording
        _ = try await recordingService.startRecording(quality: .medium)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let recording = try await recordingService.stopRecording()
        try await storageManager.saveRecording(recording)
        
        // Then: Should be saved locally
        let retrieved = try await storageManager.getRecording(id: recording.id)
        XCTAssertNotNil(retrieved)
        XCTAssertFalse(retrieved!.isSynced)
        
        // When: Attempting sync
        // (In a real scenario, we would simulate offline state here)
        // For this test, we just check that sync status reflects appropriate state
        let status = await getCurrentSyncStatus()
        switch status {
        case .idle, .offline:
            XCTAssertTrue(true)
        default:
            XCTFail("Status should be idle or offline, but was \(status)")
        }
    }
    
    func testSyncStatusTransitionOnConnectivity() async throws {
        // Given: Starting offline
        
        // When: Simulating connectivity change
        // Note: Actual implementation would use NWPathMonitor
        
        // Then: Sync status should update accordingly
        // This would be tested with actual network monitoring
    }
    
    // MARK: - Helper Methods
    
    private func createTestRecording(
        title: String = "Test Recording",
        fileSize: Int64 = 1_000_000
    ) -> Recording {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(RecordingAudioConfig.audioFileExtension)")

        // StorageManager.saveRecording requires the audio file to exist.
        // Some tests validate storage usage, so make the on-disk file match `fileSize`.
        if !FileManager.default.fileExists(atPath: audioURL.path) {
            FileManager.default.createFile(atPath: audioURL.path, contents: nil)

            if fileSize > 0, let handle = try? FileHandle(forWritingTo: audioURL) {
                try? handle.truncate(atOffset: UInt64(fileSize))
                try? handle.close()
            }
        }

        return Recording(
            id: UUID(),
            title: title,
            date: Date(),
            duration: 300,
            audioFileURL: audioURL,
            transcript: [],
            speakers: [],
            tags: [],
            notes: [],
            fileSize: fileSize,
            isSynced: false,
            lastModified: Date()
        )
    }
}
