//
//  StorageManagerProtocol.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation

/// Defines the interface for storage management operations
protocol StorageManagerProtocol {
    /// Saves a recording to local storage and Core Data
    /// - Parameter recording: The recording to save
    /// - Throws: StorageError if save fails
    func saveRecording(_ recording: Recording) async throws
    
    /// Retrieves a recording by its ID
    /// - Parameter id: The UUID of the recording
    /// - Returns: The recording if found, nil otherwise
    /// - Throws: StorageError if fetch fails
    func getRecording(id: UUID) async throws -> Recording?
    
    /// Retrieves all recordings with optional sorting
    /// - Parameter sortedBy: The sort option to use
    /// - Returns: Array of recordings
    /// - Throws: StorageError if fetch fails
    func getAllRecordings(sortedBy: SortOption) async throws -> [Recording]
    
    /// Updates an existing recording
    /// - Parameter recording: The recording with updated data
    /// - Throws: StorageError if update fails
    func updateRecording(_ recording: Recording) async throws
    
    /// Deletes a recording
    /// - Parameters:
    ///   - id: The UUID of the recording to delete
    ///   - deleteFromCloud: Whether to also delete from iCloud
    /// - Throws: StorageError if deletion fails
    func deleteRecording(id: UUID, deleteFromCloud: Bool) async throws
    
    /// Searches recordings by query string
    /// - Parameter query: The search query
    /// - Returns: Array of matching recordings
    /// - Throws: StorageError if search fails
    func searchRecordings(query: String) async throws -> [Recording]
    
    /// Filters recordings by tags
    /// - Parameter tags: Array of tags to filter by
    /// - Returns: Array of matching recordings
    /// - Throws: StorageError if filter fails
    func filterRecordings(byTags tags: [String]) async throws -> [Recording]
    
    /// Filters recordings by date range
    /// - Parameters:
    ///   - startDate: The start date of the range
    ///   - endDate: The end date of the range
    /// - Returns: Array of matching recordings
    /// - Throws: StorageError if filter fails
    func filterRecordings(from startDate: Date, to endDate: Date) async throws -> [Recording]
    
    /// Gets storage usage information
    /// - Returns: Storage usage details
    /// - Throws: StorageError if calculation fails
    func getStorageUsage() async throws -> StorageUsage
    
    /// Performs automatic cleanup based on user preferences
    /// - Parameter olderThanDays: Delete local files older than this many days
    /// - Throws: StorageError if cleanup fails
    func performAutoCleanup(olderThanDays: Int) async throws
}

/// Sort options for recordings
enum SortOption {
    case dateDescending
    case dateAscending
    case titleAscending
    case titleDescending
    case durationDescending
    case durationAscending
}

/// Storage usage information
struct StorageUsage {
    let totalBytes: Int64
    let recordingCount: Int
    let perRecordingSizes: [UUID: Int64]
    
    /// Formatted total size string
    var formattedTotalSize: String {
        formatBytes(totalBytes)
    }
    
    /// Formats bytes into human-readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let bytesDouble = Double(bytes)
        
        if bytesDouble < 1024 {
            return "\(bytes) B"
        } else if bytesDouble < 1024 * 1024 {
            return String(format: "%.1f KB", bytesDouble / 1024)
        } else if bytesDouble < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytesDouble / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytesDouble / (1024 * 1024 * 1024))
        }
    }
}
