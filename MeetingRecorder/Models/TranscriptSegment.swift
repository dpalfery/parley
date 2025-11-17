//
//  TranscriptSegment.swift
//  MeetingRecorder
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
}
