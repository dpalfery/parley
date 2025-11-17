//
//  SyncError.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation

/// Errors that can occur during cloud synchronization operations
enum SyncError: LocalizedError {
    case iCloudUnavailable
    case networkUnavailable
    case authenticationFailed
    case conflictDetected
    case uploadFailed(underlying: Error)
    case downloadFailed(underlying: Error)
    case fileCoordinationFailed(underlying: Error)
    case recordingNotFound
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud is not available. Please check your iCloud settings."
        case .networkUnavailable:
            return "Network connection is unavailable"
        case .authenticationFailed:
            return "iCloud authentication failed. Please sign in to iCloud."
        case .conflictDetected:
            return "A sync conflict was detected"
        case .uploadFailed(let error):
            return "Failed to upload to iCloud: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Failed to download from iCloud: \(error.localizedDescription)"
        case .fileCoordinationFailed(let error):
            return "File coordination failed: \(error.localizedDescription)"
        case .recordingNotFound:
            return "Recording not found for sync"
        case .invalidConfiguration:
            return "Invalid sync configuration"
        }
    }
}
