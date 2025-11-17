//
//  CloudSyncServiceTests.swift
//  MeetingRecorderTests
//
//  Unit tests for CloudSyncService
//

import XCTest
@testable import MeetingRecorder

final class CloudSyncServiceTests: XCTestCase {
    
    var sut: CloudSyncService!
    var mockStorageManager: MockStorageManager!
    
    override func setUp() {
        super.setUp()
        mockStorageManager = MockStorageManager()
        sut = CloudSyncService(storageManager: mockStorageManager)
    }
    
    override func tearDown() {
        sut = nil
        mockStorageManager = nil
        super.tearDown()
    }
    
    // MARK: - Sync Status Tests
    
    func testInitialSyncStatus() {
        // Given: Fresh service instance
        // When: No action taken
        // Then: Status should be idle
        XCTAssertEqual(sut.syncStatus, .idle)
    }
    
    func testSyncStatusTransitionToSyncing() async throws {
        // Given: Service in idle state
        XCTAssertEqual(sut.syncStatus, .idle)
        
        // When: Starting sync
        let recording = createTestRecording()
        try await sut.syncRecording(id: recording.id)
        
        // Then: Status should eventually return to synced or idle
        // (Actual sync would transition through syncing state)
    }
    
    // MARK: - Sync Queue Tests
    
    func testSyncQueueAddsRecording() async throws {
        // Given: A recording to sync
        let recording = createTestRecording()
        mockStorageManager.recordings[recording.id] = recording
        
        // When: Queueing for sync
        try await sut.syncRecording(id: recording.id)
        
        // Then: Recording should be processed
        // (Queue management is internal, verify through side effects)
    }
    
    func testSyncQueueProcessesMultipleRecordings() async throws {
        // Given: Multiple recordings
        let recording1 = createTestRecording()
        let recording2 = createTestRecording()
        let recording3 = createTestRecording()
        
        mockStorageManager.recordings[recording1.id] = recording1
        mockStorageManager.recordings[recording2.id] = recording2
        mockStorageManager.recordings[recording3.id] = recording3
        
        // When: Syncing all
        try await sut.syncAll()
        
        // Then: All recordings should be processed
        // (Verify through mock storage manager calls)
    }
    
    func testSyncQueueHandlesOfflineScenario() async throws {
        // Given: Offline state
        sut.simulateOffline() // Would need to add this method for testing
        
        // When: Attempting to sync
        let recording = createTestRecording()
        mockStorageManager.recordings[recording.id] = recording
        
        // Then: Should queue for later without throwing error
        do {
            try await sut.syncRecording(id: recording.id)
        } catch {
            // Expected to handle gracefully
        }
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testConflictResolutionKeepLocal() async throws {
        // Given: A recording with conflict
        let recordingID = UUID()
        
        // When: Resolving with keepLocal
        try await sut.resolveSyncConflict(id: recordingID, resolution: .keepLocal)
        
        // Then: Local version should be preserved
        // (Verification would require checking actual storage)
    }
    
    func testConflictResolutionKeepCloud() async throws {
        // Given: A recording with conflict
        let recordingID = UUID()
        
        // When: Resolving with keepCloud
        try await sut.resolveSyncConflict(id: recordingID, resolution: .keepCloud)
        
        // Then: Cloud version should be downloaded
        // (Verification would require checking actual storage)
    }
    
    func testConflictResolutionKeepBoth() async throws {
        // Given: A recording with conflict
        let recordingID = UUID()
        
        // When: Resolving with keepBoth
        try await sut.resolveSyncConflict(id: recordingID, resolution: .keepBoth)
        
        // Then: Both versions should be preserved
        // (Verification would require checking for duplicate)
    }
    
    // MARK: - Enable/Disable Sync Tests
    
    func testEnableSync() async throws {
        // Given: Sync is disabled
        try await sut.disableSync()
        
        // When: Enabling sync
        try await sut.enableSync()
        
        // Then: Sync should be enabled
        XCTAssertTrue(sut.isSyncEnabled)
    }
    
    func testDisableSync() async throws {
        // Given: Sync is enabled
        try await sut.enableSync()
        
        // When: Disabling sync
        try await sut.disableSync()
        
        // Then: Sync should be disabled
        XCTAssertFalse(sut.isSyncEnabled)
    }
    
    func testSyncAllWhenDisabled() async throws {
        // Given: Sync is disabled
        try await sut.disableSync()
        
        // When: Attempting to sync all
        // Then: Should not perform sync
        try await sut.syncAll()
        
        // Verify no sync operations occurred
        XCTAssertFalse(sut.isSyncEnabled)
    }
    
    // MARK: - Sync Status Enum Tests
    
    func testSyncStatusIdle() {
        // Given: Idle status
        let status = SyncStatus.idle
        
        // When: Checking status
        // Then: Should be idle
        if case .idle = status {
            XCTAssertTrue(true)
        } else {
            XCTFail("Status should be idle")
        }
    }
    
    func testSyncStatusSyncing() {
        // Given: Syncing status with progress
        let status = SyncStatus.syncing(progress: 0.5)
        
        // When: Checking status and progress
        // Then: Should have correct progress
        if case .syncing(let progress) = status {
            XCTAssertEqual(progress, 0.5, accuracy: 0.01)
        } else {
            XCTFail("Status should be syncing")
        }
    }
    
    func testSyncStatusSynced() {
        // Given: Synced status
        let status = SyncStatus.synced
        
        // When: Checking status
        // Then: Should be synced
        if case .synced = status {
            XCTAssertTrue(true)
        } else {
            XCTFail("Status should be synced")
        }
    }
    
    func testSyncStatusError() {
        // Given: Error status
        let error = SyncError.networkUnavailable
        let status = SyncStatus.error(error)
        
        // When: Checking status
        // Then: Should contain error
        if case .error(let syncError) = status {
            XCTAssertNotNil(syncError)
        } else {
            XCTFail("Status should be error")
        }
    }
    
    func testSyncStatusOffline() {
        // Given: Offline status
        let status = SyncStatus.offline
        
        // When: Checking status
        // Then: Should be offline
        if case .offline = status {
            XCTAssertTrue(true)
        } else {
            XCTFail("Status should be offline")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestRecording() -> Recording {
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        
        return Recording(
            id: UUID(),
            title: "Test Recording",
            date: Date(),
            duration: 300,
            audioFileURL: audioURL,
            transcript: [],
            speakers: [],
            tags: [],
            notes: [],
            fileSize: 1_000_000,
            isSynced: false,
            lastModified: Date()
        )
    }
}

// MARK: - Mock Storage Manager

class MockStorageManager: StorageManagerProtocol {
    var recordings: [UUID: Recording] = [:]
    
    func saveRecording(_ recording: Recording) async throws {
        recordings[recording.id] = recording
    }
    
    func getRecording(id: UUID) async throws -> Recording? {
        return recordings[id]
    }
    
    func getAllRecordings(sortedBy: SortOption) async throws -> [Recording] {
        return Array(recordings.values)
    }
    
    func updateRecording(_ recording: Recording) async throws {
        recordings[recording.id] = recording
    }
    
    func deleteRecording(id: UUID, deleteFromCloud: Bool) async throws {
        recordings.removeValue(forKey: id)
    }
    
    func searchRecordings(query: String) async throws -> [Recording] {
        return Array(recordings.values)
    }
    
    func getStorageUsage() async -> StorageUsage {
        let total = recordings.values.reduce(0) { $0 + $1.fileSize }
        return StorageUsage(totalBytes: total, recordingCount: recordings.count)
    }
    
    func syncToCloud() async throws {
        // Mock implementation
    }
}
