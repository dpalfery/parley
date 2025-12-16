//
//  TranscriptSegment.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation

/// Represents a timestamped segment of transcribed text
struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: TimeInterval
    let duration: TimeInterval
    let confidence: Float
    let speakerID: String
    var isEdited: Bool
    
    init(
        id: UUID = UUID(),
        text: String,
        timestamp: TimeInterval,
        duration: TimeInterval,
        confidence: Float,
        speakerID: String,
        isEdited: Bool = false
    ) {
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
    
    /// Whether this segment has low confidence (< 0.5)
    var isLowConfidence: Bool {
        confidence < 0.5
    }
    
    // MARK: - Methods
    
    /// Returns a copy of this segment with updated speaker ID
    /// - Parameter newSpeakerID: The new speaker ID to assign
    /// - Returns: A copy of the segment with the updated speaker ID
    func withUpdatedSpeaker(_ newSpeakerID: String) -> TranscriptSegment {
        return TranscriptSegment(
            id: self.id,
            text: self.text,
            timestamp: self.timestamp,
            duration: self.duration,
            confidence: self.confidence,
            speakerID: newSpeakerID,
            isEdited: self.isEdited
        )
    }
}
