//
//  Errors.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import os.log

/// Errors related to recording operations
enum RecordingError: LocalizedError {
    case microphonePermissionDenied
    case audioSessionConfigurationFailed
    case recordingInProgress
    case noActiveRecording
    case diskSpaceInsufficient
    case audioEngineFailure
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to record audio. Please enable it in Settings."
        case .audioSessionConfigurationFailed:
            return "Failed to configure audio session. Please try again."
        case .recordingInProgress:
            return "A recording is already in progress."
        case .noActiveRecording:
            return "No active recording to perform this operation."
        case .diskSpaceInsufficient:
            return "Not enough storage space available to save the recording."
        case .audioEngineFailure:
            return "Audio engine encountered an error. Please restart the app."
        }
    }
}

/// Errors related to transcription operations
enum TranscriptionError: LocalizedError {
    case speechRecognitionUnavailable
    case speechRecognitionPermissionDenied
    case recognitionFailed(underlying: Error)
    case audioFormatUnsupported
    case recognitionLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available on this device."
        case .speechRecognitionPermissionDenied:
            return "Speech recognition permission is required. Please enable it in Settings."
        case .recognitionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .audioFormatUnsupported:
            return "The audio format is not supported for transcription."
        case .recognitionLimitExceeded:
            return "Speech recognition limit exceeded. Please try again later."
        }
    }
}

/// Errors related to storage operations
enum StorageError: LocalizedError {
    case recordingNotFound
    case fileOperationFailed(underlying: Error)
    case corruptedData
    case quotaExceeded
    case saveContextFailed(underlying: Error)
    case encodingFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case missingRequiredFields
    case diskSpaceInsufficient
    
    var errorDescription: String? {
        switch self {
        case .recordingNotFound:
            return "The requested recording could not be found."
        case .fileOperationFailed(let error):
            return "File operation failed: \(error.localizedDescription)"
        case .corruptedData:
            return "The recording data is corrupted and cannot be loaded."
        case .quotaExceeded:
            return "Storage quota exceeded. Please free up space."
        case .saveContextFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .missingRequiredFields:
            return "Required data fields are missing."
        case .diskSpaceInsufficient:
            return "Not enough storage space available to save the recording."
        }
    }
}

/// Errors related to cloud sync operations
enum SyncError: LocalizedError {
    case iCloudUnavailable
    case networkUnavailable
    case authenticationFailed
    case conflictDetected
    case uploadFailed(underlying: Error)
    case downloadFailed(underlying: Error)
    case recordingNotFound
    case fileCoordinationFailed(underlying: Error)
    case diskSpaceInsufficient
    
    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud is not available. Please check your iCloud settings."
        case .networkUnavailable:
            return "Network connection is unavailable. Sync will resume when online."
        case .authenticationFailed:
            return "iCloud authentication failed. Please sign in to iCloud."
        case .conflictDetected:
            return "A sync conflict was detected. Please resolve the conflict."
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .recordingNotFound:
            return "The requested recording could not be found."
        case .fileCoordinationFailed(let error):
            return "File coordination failed: \(error.localizedDescription)"
        case .diskSpaceInsufficient:
            return "Not enough storage space available."
        }
    }
}

/// Errors related to speaker operations
enum SpeakerError: LocalizedError {
    case detectionFailed
    case profileNotFound
    case invalidSpeakerID
    
    var errorDescription: String? {
        switch self {
        case .detectionFailed:
            return "Failed to detect speakers in the recording."
        case .profileNotFound:
            return "Speaker profile not found."
        case .invalidSpeakerID:
            return "Invalid speaker ID provided."
        }
    }
}

// MARK: - Error Logging

/// Centralized error logging utility
struct ErrorLogger {
    private static let logger = Logger(subsystem: "com.parley.app", category: "Errors")
    
    /// Logs an error with context
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Additional context about where/when the error occurred
    static func log(_ error: Error, context: String? = nil) {
        let contextString = context.map { " [\($0)]" } ?? ""
        logger.error("Error\(contextString): \(error.localizedDescription)")
    }
    
    /// Logs a recording error
    static func log(_ error: RecordingError, context: String? = nil) {
        log(error as Error, context: context)
    }
    
    /// Logs a transcription error
    static func log(_ error: TranscriptionError, context: String? = nil) {
        log(error as Error, context: context)
    }
    
    /// Logs a storage error
    static func log(_ error: StorageError, context: String? = nil) {
        log(error as Error, context: context)
    }
    
    /// Logs a sync error
    static func log(_ error: SyncError, context: String? = nil) {
        log(error as Error, context: context)
    }
    
    /// Logs a speaker error
    static func log(_ error: SpeakerError, context: String? = nil) {
        log(error as Error, context: context)
    }
}
