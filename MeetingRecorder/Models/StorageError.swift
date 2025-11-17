//
//  StorageError.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation

/// Errors that can occur during storage operations
enum StorageError: LocalizedError {
    case recordingNotFound
    case fileOperationFailed(underlying: Error)
    case corruptedData
    case quotaExceeded
    case encodingFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case missingRequiredFields
    case saveContextFailed(underlying: Error)
    case invalidURL
    case diskSpaceInsufficient
    
    var errorDescription: String? {
        switch self {
        case .recordingNotFound:
            return "Recording not found"
        case .fileOperationFailed(let error):
            return "File operation failed: \(error.localizedDescription)"
        case .corruptedData:
            return "Data is corrupted and cannot be read"
        case .quotaExceeded:
            return "Storage quota exceeded"
        case .encodingFailed(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .missingRequiredFields:
            return "Missing required fields in data"
        case .saveContextFailed(let error):
            return "Failed to save context: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid file URL"
        case .diskSpaceInsufficient:
            return "Not enough disk space available"
        }
    }
}
