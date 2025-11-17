//
//  TranscriptionServiceProtocol.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import AVFoundation

/// Protocol defining the transcription service interface for speech-to-text conversion
protocol TranscriptionServiceProtocol {
    /// Publisher for streaming transcript segments as they are generated
    var transcriptSegments: Published<[TranscriptSegment]>.Publisher { get }
    
    /// Starts transcription from a recorded audio file
    /// - Parameter audioURL: URL of the audio file to transcribe
    /// - Throws: TranscriptionError if transcription cannot be started
    func startTranscription(audioURL: URL) async throws
    
    /// Starts real-time transcription from live audio buffer
    /// - Parameter audioBuffer: Audio buffer containing live audio data
    /// - Throws: TranscriptionError if live transcription cannot be started
    func startLiveTranscription(audioBuffer: AVAudioPCMBuffer) async throws
    
    /// Stops the current transcription process
    func stopTranscription() async
    
    /// Retrieves the complete transcript generated so far
    /// - Returns: Array of all transcript segments
    func getFullTranscript() async -> [TranscriptSegment]
}

/// Represents a single segment of transcribed text with metadata
struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: TimeInterval
    let duration: TimeInterval
    let confidence: Float
    let speakerID: String
    var isEdited: Bool
    
    init(id: UUID = UUID(), text: String, timestamp: TimeInterval, duration: TimeInterval, confidence: Float, speakerID: String, isEdited: Bool = false) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.confidence = confidence
        self.speakerID = speakerID
        self.isEdited = isEdited
    }
    
    // MARK: - Computed Properties
    
    /// Formatted timestamp string (MM:SS)
    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// End time of the segment
    var endTime: TimeInterval {
        timestamp + duration
    }
    
    /// Whether this segment has low confidence (< 0.5)
    var isLowConfidence: Bool {
        confidence < 0.5
    }
    
    // MARK: - Helper Methods
    
    /// Creates a copy of the segment with updated text
    func withUpdatedText(_ newText: String) -> TranscriptSegment {
        TranscriptSegment(
            id: id,
            text: newText,
            timestamp: timestamp,
            duration: duration,
            confidence: confidence,
            speakerID: speakerID,
            isEdited: true
        )
    }
    
    /// Creates a copy of the segment with updated speaker ID
    func withUpdatedSpeaker(_ newSpeakerID: String) -> TranscriptSegment {
        TranscriptSegment(
            id: id,
            text: text,
            timestamp: timestamp,
            duration: duration,
            confidence: confidence,
            speakerID: newSpeakerID,
            isEdited: true
        )
    }
}
