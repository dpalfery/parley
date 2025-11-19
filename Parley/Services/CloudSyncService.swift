//
//  CloudSyncService.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import Network
import os.log

/// Implementation of CloudSyncServiceProtocol for iCloud Drive synchronization
final class CloudSyncService: CloudSyncServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private var _syncStatus: SyncStatus = .idle
    var syncStatus: Published<SyncStatus>.Publisher { $_syncStatus }
    
    // MARK: - Private Properties
    
    private let fileManager: FileManager
    private let storageManager: StorageManagerProtocol
    private let logger = Logger(subsystem: "com.meetingrecorder.app", category: "CloudSyncService")
    
    private var iCloudContainerURL: URL?
    private var isSyncEnabled: Bool = false
    private var syncQueue: [UUID] = []
    private var pathMonitor: NWPathMonitor?
    private var isOnline: Bool = true
    
    private let syncQueueLock = NSLock()
    private let userDefaults = UserDefaults.standard
    private let syncEnabledKey = "com.meetingrecorder.iCloudSyncEnabled"
    
    // MARK: - Initialization
    
    /// Initializes the cloud sync service
    /// - Parameter storageManager: The storage manager for local operations
    init(storageManager: StorageManagerProtocol) {
        self.fileManager = FileManager.default
        self.storageManager = storageManager
        
        // Load sync enabled preference
        self.isSyncEnabled = userDefaults.bool(forKey: syncEnabledKey)
        
        // Setup iCloud container
        setupiCloudContainer()
        
        // Setup network monitoring
        setupNetworkMonitoring()
        
        // Process pending sync queue if sync is enabled
        if isSyncEnabled {
            Task {
                await processSyncQueue()
            }
        }
    }
    
    deinit {
        pathMonitor?.cancel()
    }
    
    // MARK: - iCloud Setup
    
    /// Sets up the iCloud container URL and directory structure
    private func setupiCloudContainer() {
        // Get iCloud container URL
        iCloudContainerURL = fileManager.url(forUbiquityContainerIdentifier: nil)
        
        if let containerURL = iCloudContainerURL {
            logger.info("iCloud container URL: \(containerURL.path)")
            
            // Create directory structure
            let recordingsURL = containerURL
                .appendingPathComponent("Documents")
                .appendingPathComponent("MeetingRecorder")
                .appendingPathComponent("Recordings")
            
            do {
                try fileManager.createDirectory(
                    at: recordingsURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                logger.info("iCloud directory structure created")
            } catch {
                logger.error("Failed to create iCloud directory structure: \(error.localizedDescription)")
            }
        } else {
            logger.warning("iCloud container URL is nil - iCloud may not be available")
        }
    }
    
    /// Checks if iCloud is available
    /// - Returns: True if iCloud is available
    private func checkiCloudAvailability() -> Bool {
        // Check for ubiquity identity token
        guard fileManager.ubiquityIdentityToken != nil else {
            logger.warning("iCloud ubiquity identity token is nil")
            return false
        }
        
        // Check for container URL
        guard iCloudContainerURL != nil else {
            logger.warning("iCloud container URL is nil")
            return false
        }
        
        return true
    }
    
    /// Gets the iCloud directory URL for a specific recording
    /// - Parameter recordingID: The UUID of the recording
    /// - Returns: The iCloud directory URL
    /// - Throws: SyncError if iCloud is unavailable
    private func getiCloudRecordingURL(for recordingID: UUID) throws -> URL {
        guard let containerURL = iCloudContainerURL else {
            throw SyncError.iCloudUnavailable
        }
        
        return containerURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("MeetingRecorder")
            .appendingPathComponent("Recordings")
            .appendingPathComponent(recordingID.uuidString)
    }
    
    // MARK: - Network Monitoring
    
    /// Sets up network connectivity monitoring
    private func setupNetworkMonitoring() {
        pathMonitor = NWPathMonitor()
        
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let wasOnline = self.isOnline
            self.isOnline = path.status == .satisfied
            
            if !wasOnline && self.isOnline {
                self.logger.info("Network connectivity restored")
                
                // Update status if we were offline
                if case .offline = self._syncStatus {
                    self._syncStatus = .idle
                }
                
                // Process pending sync queue
                if self.isSyncEnabled {
                    Task {
                        await self.processSyncQueue()
                    }
                }
            } else if wasOnline && !self.isOnline {
                self.logger.info("Network connectivity lost")
                self._syncStatus = .offline
            }
        }
        
        let queue = DispatchQueue(label: "com.meetingrecorder.networkmonitor")
        pathMonitor?.start(queue: queue)
    }
    
    // MARK: - CloudSyncServiceProtocol Implementation
    
    func enableSync() async throws {
        logger.info("Enabling iCloud sync")
        
        // Check iCloud availability
        guard checkiCloudAvailability() else {
            throw SyncError.iCloudUnavailable
        }
        
        // Update preference
        isSyncEnabled = true
        userDefaults.set(true, forKey: syncEnabledKey)
        
        // Process any pending syncs
        await processSyncQueue()
        
        logger.info("iCloud sync enabled")
    }
    
    func disableSync() async throws {
        logger.info("Disabling iCloud sync")
        
        // Update preference
        isSyncEnabled = false
        userDefaults.set(false, forKey: syncEnabledKey)
        
        // Clear sync queue
        await clearSyncQueue()
        
        // Update status
        _syncStatus = .idle
        
        logger.info("iCloud sync disabled")
    }
    
    func syncRecording(id: UUID) async throws {
        logger.info("Syncing recording: \(id.uuidString)")
        
        // Check if sync is enabled
        guard isSyncEnabled else {
            logger.warning("Sync is disabled, skipping")
            return
        }
        
        // Check iCloud availability
        guard checkiCloudAvailability() else {
            throw SyncError.iCloudUnavailable
        }
        
        // Check network connectivity
        guard isOnline else {
            logger.info("Offline - queueing recording for sync")
            addToSyncQueue(id)
            _syncStatus = .offline
            return
        }
        
        // Update status
        _syncStatus = .syncing(progress: 0.0)
        
        do {
            // Get recording from storage
            guard let recording = try await storageManager.getRecording(id: id) else {
                throw SyncError.recordingNotFound
            }
            
            // Get local recording directory
            let localRecordingDir = getLocalRecordingDirectory(for: id)
            
            // Get iCloud recording directory
            let iCloudRecordingDir = try getiCloudRecordingURL(for: id)
            
            // Create iCloud directory
            try fileManager.createDirectory(
                at: iCloudRecordingDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Upload audio file
            let localAudioURL = localRecordingDir.appendingPathComponent(RecordingAudioConfig.audioFileName)
            let iCloudAudioURL = iCloudRecordingDir.appendingPathComponent(RecordingAudioConfig.audioFileName)
            
            try await uploadFile(from: localAudioURL, to: iCloudAudioURL)
            _syncStatus = .syncing(progress: 0.5)
            
            // Upload metadata file
            let localMetadataURL = localRecordingDir.appendingPathComponent("metadata.json")
            let iCloudMetadataURL = iCloudRecordingDir.appendingPathComponent("metadata.json")
            
            try await uploadFile(from: localMetadataURL, to: iCloudMetadataURL)
            _syncStatus = .syncing(progress: 0.8)
            
            // Update recording sync status
            var updatedRecording = recording
            updatedRecording.isSynced = true
            updatedRecording.lastModified = Date()
            try await storageManager.updateRecording(updatedRecording)
            
            // Remove from sync queue if present
            removeFromSyncQueue(id)
            
            // Update status
            _syncStatus = .synced
            
            logger.info("Recording synced successfully: \(id.uuidString)")
            
        } catch {
            logger.error("Failed to sync recording: \(error.localizedDescription)")
            _syncStatus = .error(error)
            
            // Add to sync queue for retry
            addToSyncQueue(id)
            
            throw SyncError.uploadFailed(underlying: error)
        }
    }
    
    func syncAll() async throws {
        logger.info("Syncing all recordings")
        
        // Check if sync is enabled
        guard isSyncEnabled else {
            logger.warning("Sync is disabled, skipping")
            return
        }
        
        // Check iCloud availability
        guard checkiCloudAvailability() else {
            throw SyncError.iCloudUnavailable
        }
        
        // Check network connectivity
        guard isOnline else {
            logger.info("Offline - cannot sync all recordings")
            _syncStatus = .offline
            throw SyncError.networkUnavailable
        }
        
        // Get all unsynced recordings
        let allRecordings = try await storageManager.getAllRecordings(sortedBy: .dateDescending)
        let unsyncedRecordings = allRecordings.filter { !$0.isSynced }
        
        logger.info("Found \(unsyncedRecordings.count) unsynced recordings")
        
        // Sync each recording
        for (index, recording) in unsyncedRecordings.enumerated() {
            let progress = Double(index) / Double(unsyncedRecordings.count)
            _syncStatus = .syncing(progress: progress)
            
            do {
                try await syncRecording(id: recording.id)
            } catch {
                logger.error("Failed to sync recording \(recording.id.uuidString): \(error.localizedDescription)")
                // Continue with next recording
            }
        }
        
        _syncStatus = .synced
        logger.info("Batch sync completed")
    }
    
    func resolveSyncConflict(id: UUID, resolution: ConflictResolution) async throws {
        logger.info("Resolving sync conflict for recording: \(id.uuidString) with resolution: \(resolution)")
        
        // Get local recording
        guard let localRecording = try await storageManager.getRecording(id: id) else {
            throw SyncError.recordingNotFound
        }
        
        // Get iCloud recording directory
        let iCloudRecordingDir = try getiCloudRecordingURL(for: id)
        let iCloudMetadataURL = iCloudRecordingDir.appendingPathComponent("metadata.json")
        
        switch resolution {
        case .keepLocal:
            // Upload local version to iCloud, overwriting cloud version
            try await syncRecording(id: id)
            logger.info("Conflict resolved: kept local version")
            
        case .keepCloud:
            // Download cloud version, overwriting local version
            // Read cloud metadata
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            var cloudRecording: Recording?
            
            coordinator.coordinate(readingItemAt: iCloudMetadataURL, options: [], error: &coordinationError) { url in
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    cloudRecording = try decoder.decode(Recording.self, from: data)
                } catch {
                    logger.error("Failed to read cloud metadata: \(error.localizedDescription)")
                }
            }
            
            if let error = coordinationError {
                throw SyncError.fileCoordinationFailed(underlying: error)
            }
            
            guard let cloudRecording = cloudRecording else {
                throw SyncError.downloadFailed(underlying: NSError(
                    domain: "CloudSyncService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to read cloud recording"]
                ))
            }
            
            // Update local recording with cloud data
            try await storageManager.updateRecording(cloudRecording)
            logger.info("Conflict resolved: kept cloud version")
            
        case .keepBoth:
            // Create a copy of the local recording with a new ID
            var newRecording = localRecording
            newRecording.id = UUID()
            newRecording.title = "\(localRecording.title) (Copy)"
            newRecording.isSynced = false
            
            // Save the copy
            try await storageManager.saveRecording(newRecording)
            
            // Then download cloud version to original ID
            try await resolveSyncConflict(id: id, resolution: .keepCloud)
            
            logger.info("Conflict resolved: kept both versions")
        }
    }
    
    /// Deletes a recording from iCloud
    /// - Parameter id: UUID of the recording to delete
    /// - Throws: SyncError if deletion fails
    func deleteFromCloud(id: UUID) async throws {
        logger.info("Deleting recording from iCloud: \(id.uuidString)")
        
        // Check iCloud availability
        guard checkiCloudAvailability() else {
            throw SyncError.iCloudUnavailable
        }
        
        // Get iCloud recording directory
        let iCloudRecordingDir = try getiCloudRecordingURL(for: id)
        
        // Check if directory exists
        guard fileManager.fileExists(atPath: iCloudRecordingDir.path) else {
            logger.info("Recording not found in iCloud: \(id.uuidString)")
            return
        }
        
        // Delete using NSFileCoordinator
        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            
            coordinator.coordinate(
                writingItemAt: iCloudRecordingDir,
                options: .forDeleting,
                error: &coordinationError
            ) { url in
                do {
                    try fileManager.removeItem(at: url)
                    logger.info("Recording deleted from iCloud: \(id.uuidString)")
                    continuation.resume()
                } catch {
                    logger.error("Failed to delete from iCloud: \(error.localizedDescription)")
                    continuation.resume(throwing: SyncError.uploadFailed(underlying: error))
                }
            }
            
            if let error = coordinationError {
                logger.error("File coordination failed for deletion: \(error.localizedDescription)")
                continuation.resume(throwing: SyncError.fileCoordinationFailed(underlying: error))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Gets the local recording directory URL
    /// - Parameter recordingID: The UUID of the recording
    /// - Returns: The local directory URL
    private func getLocalRecordingDirectory(for recordingID: UUID) -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL
            .appendingPathComponent("Recordings")
            .appendingPathComponent(recordingID.uuidString)
    }
    
    /// Uploads a file to iCloud using NSFileCoordinator
    /// - Parameters:
    ///   - sourceURL: The local file URL
    ///   - destinationURL: The iCloud file URL
    /// - Throws: SyncError if upload fails
    private func uploadFile(from sourceURL: URL, to destinationURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            
            coordinator.coordinate(
                readingItemAt: sourceURL,
                options: [],
                writingItemAt: destinationURL,
                options: .forReplacing,
                error: &coordinationError
            ) { readURL, writeURL in
                do {
                    // Remove existing file if present
                    if fileManager.fileExists(atPath: writeURL.path) {
                        try fileManager.removeItem(at: writeURL)
                    }
                    
                    // Copy file to iCloud
                    try fileManager.copyItem(at: readURL, to: writeURL)
                    
                    logger.info("File uploaded: \(writeURL.lastPathComponent)")
                    continuation.resume()
                    
                } catch {
                    logger.error("Failed to upload file: \(error.localizedDescription)")
                    continuation.resume(throwing: SyncError.uploadFailed(underlying: error))
                }
            }
            
            if let error = coordinationError {
                logger.error("File coordination failed: \(error.localizedDescription)")
                continuation.resume(throwing: SyncError.fileCoordinationFailed(underlying: error))
            }
        }
    }
    
    // MARK: - Sync Queue Management
    
    /// Adds a recording to the sync queue
    /// - Parameter recordingID: The UUID of the recording
    private func addToSyncQueue(_ recordingID: UUID) {
        syncQueueLock.withLock {
            if !syncQueue.contains(recordingID) {
                syncQueue.append(recordingID)
                logger.info("Added recording to sync queue: \(recordingID.uuidString)")
            }
        }
    }
    
    /// Removes a recording from the sync queue
    /// - Parameter recordingID: The UUID of the recording
    private func removeFromSyncQueue(_ recordingID: UUID) {
        syncQueueLock.withLock {
            if let index = syncQueue.firstIndex(of: recordingID) {
                syncQueue.remove(at: index)
                logger.info("Removed recording from sync queue: \(recordingID.uuidString)")
            }
        }
    }
    
    /// Clears the sync queue (async-safe)
    private func clearSyncQueue() async {
        await Task { @MainActor in
            syncQueueLock.withLock {
                syncQueue.removeAll()
            }
        }.value
    }
    
    /// Gets a copy of the sync queue (async-safe)
    private func getSyncQueueCopy() async -> [UUID] {
        return await Task { @MainActor in
            syncQueueLock.withLock {
                return syncQueue
            }
        }.value
    }
    
    /// Processes the sync queue
    private func processSyncQueue() async {
        let queueCopy = await getSyncQueueCopy()
        
        guard !queueCopy.isEmpty else {
            return
        }
        
        logger.info("Processing sync queue with \(queueCopy.count) items")
        
        for recordingID in queueCopy {
            do {
                try await syncRecording(id: recordingID)
            } catch {
                logger.error("Failed to sync queued recording: \(error.localizedDescription)")
                // Keep in queue for next attempt
            }
        }
    }
}
