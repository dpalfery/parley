//
//  CloudSyncServiceProtocol.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation
import Combine

/// Protocol defining the cloud sync service interface for iCloud synchronization
protocol CloudSyncServiceProtocol: AnyObject {
    /// Publisher for current sync status
    var syncStatus: Published<SyncStatus>.Publisher { get }
    
    /// Enables cloud synchronization
    /// - Throws: SyncError if sync cannot be enabled
    func enableSync() async throws
    
    /// Disables cloud synchronization
    /// - Throws: SyncError if sync cannot be disabled
    func disableSync() async throws
    
    /// Synchronizes a specific recording to the cloud
    /// - Parameter id: UUID of the recording to sync
    /// - Throws: SyncError if sync fails
    func syncRecording(id: UUID) async throws
    
    /// Synchronizes all pending recordings to the cloud
    /// - Throws: SyncError if batch sync fails
    func syncAll() async throws
    
    /// Resolves a sync conflict for a recording
    /// - Parameters:
    ///   - id: UUID of the recording with conflict
    ///   - resolution: Strategy for resolving the conflict
    /// - Throws: SyncError if conflict resolution fails
    func resolveSyncConflict(id: UUID, resolution: ConflictResolution) async throws
    
    /// Deletes a recording from iCloud
    /// - Parameter id: UUID of the recording to delete
    /// - Throws: SyncError if deletion fails
    func deleteFromCloud(id: UUID) async throws
}

/// Represents the current synchronization status
enum SyncStatus {
    case idle
    case syncing(progress: Double)
    case synced
    case error(Error)
    case offline
}

/// Strategies for resolving sync conflicts
enum ConflictResolution: CustomStringConvertible {
    case keepLocal
    case keepCloud
    case keepBoth
    
    var description: String {
        switch self {
        case .keepLocal:
            return "keepLocal"
        case .keepCloud:
            return "keepCloud"
        case .keepBoth:
            return "keepBoth"
        }
    }
}
