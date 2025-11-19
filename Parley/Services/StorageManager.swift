//
//  StorageManager.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import CoreData
import Foundation

/// Manages local file storage and Core Data operations for recordings
class StorageManager: StorageManagerProtocol {
    private let persistenceController: PersistenceController
    private let fileManager: FileManager
    private let recordingsDirectory: URL
    weak var cloudSyncService: CloudSyncServiceProtocol?
    
    /// Initializes the storage manager
    /// - Parameter persistenceController: The Core Data persistence controller
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.fileManager = FileManager.default
        
        // Set up recordings directory
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.recordingsDirectory = documentsURL.appendingPathComponent("Recordings")
        
        // Create recordings directory if it doesn't exist
        try? fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - File Storage Operations
    
    /// Creates the directory structure for a recording
    /// - Parameter recordingID: The UUID of the recording
    /// - Returns: The directory URL for the recording
    /// - Throws: StorageError if directory creation fails
    private func createRecordingDirectory(for recordingID: UUID) throws -> URL {
        let recordingDir = recordingsDirectory.appendingPathComponent(recordingID.uuidString)
        
        do {
            try fileManager.createDirectory(at: recordingDir, withIntermediateDirectories: true)
            
            // Enable file protection
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: recordingDir.path
            )
            
            return recordingDir
        } catch {
            throw StorageError.fileOperationFailed(underlying: error)
        }
    }
    
    /// Saves audio file to the recording directory
    /// - Parameters:
    ///   - sourceURL: The source URL of the audio file
    ///   - recordingID: The UUID of the recording
    /// - Returns: The destination URL of the saved audio file
    /// - Throws: StorageError if save fails
    private func saveAudioFile(from sourceURL: URL, for recordingID: UUID) throws -> URL {
        let recordingDir = try createRecordingDirectory(for: recordingID)
        let destinationURL = recordingDir.appendingPathComponent(RecordingAudioConfig.audioFileName)
        
        do {
            // Check if source file exists
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw StorageError.fileOperationFailed(underlying: NSError(
                    domain: "StorageManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Source audio file not found"]
                ))
            }
            
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // Copy file to destination
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            // Enable file protection
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: destinationURL.path
            )
            
            return destinationURL
        } catch {
            throw StorageError.fileOperationFailed(underlying: error)
        }
    }
    
    /// Saves metadata JSON file
    /// - Parameters:
    ///   - recording: The recording to save metadata for
    ///   - recordingID: The UUID of the recording
    /// - Throws: StorageError if save fails
    private func saveMetadata(for recording: Recording, recordingID: UUID) throws {
        let recordingDir = recordingsDirectory.appendingPathComponent(recordingID.uuidString)
        let metadataURL = recordingDir.appendingPathComponent("metadata.json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let metadataData = try encoder.encode(recording)
            try metadataData.write(to: metadataURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw StorageError.encodingFailed(underlying: error)
        }
    }
    
    /// Calculates the file size of a recording
    /// - Parameter recordingID: The UUID of the recording
    /// - Returns: The total file size in bytes
    private func calculateFileSize(for recordingID: UUID) -> Int64 {
        let recordingDir = recordingsDirectory.appendingPathComponent(recordingID.uuidString)
        
        guard let enumerator = fileManager.enumerator(at: recordingDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
    
    /// Checks if there's sufficient disk space
    /// - Parameter requiredBytes: The number of bytes required
    /// - Returns: True if sufficient space is available
    private func hasSufficientDiskSpace(requiredBytes: Int64) -> Bool {
        guard let systemAttributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSize = systemAttributes[.systemFreeSize] as? NSNumber else {
            return false
        }
        
        let freeBytes = freeSize.int64Value
        let bufferBytes: Int64 = 100 * 1024 * 1024 // 100 MB buffer
        
        return freeBytes > (requiredBytes + bufferBytes)
    }

    // MARK: - Core Data Operations
    
    /// Saves a recording to local storage and Core Data
    func saveRecording(_ recording: Recording) async throws {
        // Check disk space
        let estimatedSize = recording.fileSize > 0 ? recording.fileSize : 10 * 1024 * 1024 // 10 MB estimate
        guard hasSufficientDiskSpace(requiredBytes: estimatedSize) else {
            throw StorageError.diskSpaceInsufficient
        }
        
        // Save audio file
        let savedAudioURL = try saveAudioFile(from: recording.audioFileURL, for: recording.id)
        
        // Calculate actual file size
        let actualFileSize = calculateFileSize(for: recording.id)
        
        // Create updated recording with correct file size and URL
        var updatedRecording = recording
        updatedRecording.fileSize = actualFileSize
        
        // Save metadata JSON
        try saveMetadata(for: updatedRecording, recordingID: recording.id)
        
        // Save to Core Data
        let context = persistenceController.viewContext
        
        try await context.perform {
            let entity = try RecordingEntity.from(recording: updatedRecording, context: context)
            try context.save()
        }
    }
    
    /// Retrieves a recording by its ID
    func getRecording(id: UUID) async throws -> Recording? {
        let context = persistenceController.viewContext
        
        return try await context.perform {
            let fetchRequest = RecordingEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            let results = try context.fetch(fetchRequest)
            return try results.first?.toRecording()
        }
    }
    
    /// Retrieves all recordings with optional sorting
    func getAllRecordings(sortedBy sortOption: SortOption = .dateDescending) async throws -> [Recording] {
        let context = persistenceController.viewContext
        
        return try await context.perform {
            let fetchRequest = RecordingEntity.fetchRequest()
            
            // Apply sorting
            let sortDescriptor: NSSortDescriptor
            switch sortOption {
            case .dateDescending:
                sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
            case .dateAscending:
                sortDescriptor = NSSortDescriptor(key: "date", ascending: true)
            case .titleAscending:
                sortDescriptor = NSSortDescriptor(key: "title", ascending: true)
            case .titleDescending:
                sortDescriptor = NSSortDescriptor(key: "title", ascending: false)
            case .durationDescending:
                sortDescriptor = NSSortDescriptor(key: "duration", ascending: false)
            case .durationAscending:
                sortDescriptor = NSSortDescriptor(key: "duration", ascending: true)
            }
            
            fetchRequest.sortDescriptors = [sortDescriptor]
            
            // Performance optimizations
            fetchRequest.fetchBatchSize = 20
            fetchRequest.returnsObjectsAsFaults = false
            
            let results = try context.fetch(fetchRequest)
            return try results.toRecordings()
        }
    }
    
    /// Updates an existing recording
    func updateRecording(_ recording: Recording) async throws {
        let context = persistenceController.viewContext
        
        try await context.perform {
            let fetchRequest = RecordingEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", recording.id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            guard let entity = try context.fetch(fetchRequest).first else {
                throw StorageError.recordingNotFound
            }
            
            try entity.update(from: recording)
            try context.save()
        }
        
        // Update metadata JSON
        try saveMetadata(for: recording, recordingID: recording.id)
    }
    
    /// Deletes a recording
    func deleteRecording(id: UUID, deleteFromCloud: Bool = false) async throws {
        let context = persistenceController.viewContext
        
        // Delete from Core Data
        try await context.perform {
            let fetchRequest = RecordingEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            guard let entity = try context.fetch(fetchRequest).first else {
                throw StorageError.recordingNotFound
            }
            
            context.delete(entity)
            try context.save()
        }
        
        // Delete local files
        let recordingDir = recordingsDirectory.appendingPathComponent(id.uuidString)
        if fileManager.fileExists(atPath: recordingDir.path) {
            do {
                try fileManager.removeItem(at: recordingDir)
            } catch {
                throw StorageError.fileOperationFailed(underlying: error)
            }
        }
        
        // Delete from cloud if requested
        if deleteFromCloud, let cloudSync = cloudSyncService {
            do {
                try await cloudSync.deleteFromCloud(id: id)
            } catch {
                // Log error but don't fail the entire operation
                // Local deletion was successful
                print("Warning: Failed to delete from cloud: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Search and Filtering
    
    /// Searches recordings by query string
    func searchRecordings(query: String) async throws -> [Recording] {
        guard !query.isEmpty else {
            return try await getAllRecordings(sortedBy: .dateDescending)
        }
        
        let context = persistenceController.viewContext
        
        return try await context.perform {
            let fetchRequest = RecordingEntity.fetchRequest()
            
            // Search in searchableContent field
            let searchQuery = query.lowercased()
            fetchRequest.predicate = NSPredicate(format: "searchableContent CONTAINS[cd] %@", searchQuery)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            // Performance optimizations
            fetchRequest.fetchBatchSize = 20
            fetchRequest.returnsObjectsAsFaults = false
            
            let results = try context.fetch(fetchRequest)
            return try results.toRecordings()
        }
    }
    
    /// Filters recordings by tags
    func filterRecordings(byTags tags: [String]) async throws -> [Recording] {
        guard !tags.isEmpty else {
            return try await getAllRecordings(sortedBy: .dateDescending)
        }
        
        // Get all recordings and filter in memory (since tags are stored as JSON)
        let allRecordings = try await getAllRecordings(sortedBy: .dateDescending)
        
        return allRecordings.filter { recording in
            !Set(recording.tags).isDisjoint(with: Set(tags))
        }
    }
    
    /// Filters recordings by date range
    func filterRecordings(from startDate: Date, to endDate: Date) async throws -> [Recording] {
        let context = persistenceController.viewContext
        
        return try await context.perform {
            let fetchRequest = RecordingEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as CVarArg, endDate as CVarArg)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            // Performance optimizations
            fetchRequest.fetchBatchSize = 20
            fetchRequest.returnsObjectsAsFaults = false
            
            let results = try context.fetch(fetchRequest)
            return try results.toRecordings()
        }
    }
    
    // MARK: - Storage Usage
    
    /// Gets storage usage information
    func getStorageUsage() async throws -> StorageUsage {
        let recordings = try await getAllRecordings(sortedBy: .dateDescending)
        
        var totalBytes: Int64 = 0
        var perRecordingSizes: [UUID: Int64] = [:]
        
        for recording in recordings {
            let size = calculateFileSize(for: recording.id)
            totalBytes += size
            perRecordingSizes[recording.id] = size
        }
        
        return StorageUsage(
            totalBytes: totalBytes,
            recordingCount: recordings.count,
            perRecordingSizes: perRecordingSizes
        )
    }
    
    // MARK: - Automatic Cleanup
    
    /// Performs automatic cleanup based on user preferences
    func performAutoCleanup(olderThanDays days: Int) async throws {
        guard days > 0 else { return }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recordings = try await getAllRecordings(sortedBy: .dateAscending)
        
        for recording in recordings {
            // Only delete local files if recording is synced and older than cutoff
            if recording.date < cutoffDate && recording.isSynced {
                // Delete only local files, preserve Core Data entry and cloud copy
                let recordingDir = recordingsDirectory.appendingPathComponent(recording.id.uuidString)
                if fileManager.fileExists(atPath: recordingDir.path) {
                    try? fileManager.removeItem(at: recordingDir)
                }
            }
        }
    }
}
