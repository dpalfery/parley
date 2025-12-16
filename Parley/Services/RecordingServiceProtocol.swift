//
//  RecordingServiceProtocol.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import AVFoundation

/// Protocol defining the recording service interface for audio capture and management
protocol RecordingServiceProtocol {
    /// Publisher for the current recording state
    var recordingState: Published<RecordingState>.Publisher { get }
    
    /// Publisher for real-time audio level (0.0 to 1.0)
    var audioLevel: Published<Float>.Publisher { get }
    
    /// Publisher for elapsed recording duration in seconds
    var duration: Published<TimeInterval>.Publisher { get }
    
    /// Publisher for audio buffers captured during recording
    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> { get }
    
    /// Starts a new recording session with specified audio quality
    /// - Parameter quality: The audio quality setting for the recording
    /// - Returns: A RecordingSession object representing the active session
    /// - Throws: RecordingError if recording cannot be started
    func startRecording(quality: AudioQuality) async throws -> RecordingSession
    
    /// Pauses the current recording session
    /// - Throws: RecordingError if no active recording or pause fails
    func pauseRecording() async throws
    
    /// Resumes a paused recording session
    /// - Throws: RecordingError if no paused recording or resume fails
    func resumeRecording() async throws
    
    /// Stops the current recording and finalizes the audio file
    /// - Returns: A Recording object with complete metadata
    /// - Throws: RecordingError if no active recording or stop fails
    func stopRecording() async throws -> Recording
    
    /// Cancels the current recording without saving
    /// - Throws: RecordingError if cancellation fails
    func cancelRecording() async throws
}

/// Represents the current state of the recording system
enum RecordingState {
    case idle
    case recording
    case paused
    case processing
}

/// Audio quality settings for recordings
enum AudioQuality: Int, CaseIterable, Identifiable, CustomStringConvertible {
    case low = 0      // 64 kbps
    case medium = 1   // 128 kbps
    case high = 2     // 256 kbps

    var id: Int { rawValue }
    
    var bitRate: Int {
        switch self {
        case .low: return 64000
        case .medium: return 128000
        case .high: return 256000
        }
    }

    var displayName: String {
        switch self {
        case .low: return "Low (64 kbps)"
        case .medium: return "Medium (128 kbps)"
        case .high: return "High (256 kbps)"
        }
    }
    
    var description: String {
        return displayName
    }
}

/// Represents an active recording session
struct RecordingSession {
    let id: UUID
    let startTime: Date
    let quality: AudioQuality
    let audioFileURL: URL
}