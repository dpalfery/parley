//
//  SpeakerServiceProtocol.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation

/// Protocol defining the speaker service interface for speaker diarization and identification
protocol SpeakerServiceProtocol {
    /// Detects and identifies speakers in an audio recording
    /// - Parameter audioURL: URL of the audio file to analyze
    /// - Returns: Array of speaker segments with timing information
    /// - Throws: SpeakerError if speaker detection fails
    func detectSpeakers(audioURL: URL) async throws -> [SpeakerSegment]
    
    /// Assigns a speaker profile to a specific transcript segment
    /// - Parameters:
    ///   - segmentID: UUID of the transcript segment
    ///   - speakerID: ID of the speaker to assign
    /// - Throws: SpeakerError if assignment fails
    func assignSpeakerToSegment(segmentID: UUID, speakerID: String) async throws
    
    /// Updates the display name for a speaker profile
    /// - Parameters:
    ///   - speakerID: ID of the speaker to update
    ///   - name: New display name for the speaker
    /// - Throws: SpeakerError if update fails
    func updateSpeakerName(speakerID: String, name: String) async throws
    
    /// Retrieves a speaker profile by ID
    /// - Parameter speakerID: ID of the speaker to retrieve
    /// - Returns: SpeakerProfile if found, nil otherwise
    func getSpeakerProfile(speakerID: String) async -> SpeakerProfile?
}

/// Represents a time segment associated with a specific speaker
struct SpeakerSegment {
    let speakerID: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    
    // MARK: - Computed Properties
    
    /// Duration of the speaker segment
    var duration: TimeInterval {
        endTime - startTime
    }
    
    /// Formatted time range string (MM:SS - MM:SS)
    var formattedTimeRange: String {
        let startMinutes = Int(startTime) / 60
        let startSeconds = Int(startTime) % 60
        let endMinutes = Int(endTime) / 60
        let endSeconds = Int(endTime) % 60
        return String(format: "%02d:%02d - %02d:%02d", startMinutes, startSeconds, endMinutes, endSeconds)
    }
    
    // MARK: - Helper Methods
    
    /// Checks if a given timestamp falls within this segment
    func contains(timestamp: TimeInterval) -> Bool {
        timestamp >= startTime && timestamp <= endTime
    }
}

/// Represents a speaker profile with voice characteristics
struct SpeakerProfile: Identifiable, Codable {
    let id: String
    var displayName: String
    let voiceCharacteristics: Data
    let createdAt: Date
    var lastUsed: Date
    
    init(id: String, displayName: String, voiceCharacteristics: Data, createdAt: Date, lastUsed: Date) {
        self.id = id
        self.displayName = displayName
        self.voiceCharacteristics = voiceCharacteristics
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
    
    // MARK: - Helper Methods
    
    /// Creates a copy with updated display name
    func withUpdatedName(_ newName: String) -> SpeakerProfile {
        SpeakerProfile(
            id: id,
            displayName: newName,
            voiceCharacteristics: voiceCharacteristics,
            createdAt: createdAt,
            lastUsed: Date()
        )
    }
    
    /// Creates a copy with updated last used timestamp
    func withUpdatedLastUsed() -> SpeakerProfile {
        SpeakerProfile(
            id: id,
            displayName: displayName,
            voiceCharacteristics: voiceCharacteristics,
            createdAt: createdAt,
            lastUsed: Date()
        )
    }
}
