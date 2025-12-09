//
//  SpeakerProfile.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation

/// Represents a speaker profile with voice characteristics
struct SpeakerProfile: Identifiable, Codable {
    let id: String
    var displayName: String
    let voiceCharacteristics: Data
    let createdAt: Date
    var lastUsed: Date
    
    init(
        id: String,
        displayName: String,
        voiceCharacteristics: Data = Data(),
        createdAt: Date = Date(),
        lastUsed: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.voiceCharacteristics = voiceCharacteristics
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
    
    // MARK: - Helper Methods
    
    /// Returns a new profile with updated display name
    func withUpdatedName(_ name: String) -> SpeakerProfile {
        var copy = self
        copy.displayName = name
        copy.lastUsed = Date()
        return copy
    }
    
    /// Returns a new profile with updated last used timestamp
    func withUpdatedLastUsed() -> SpeakerProfile {
        var copy = self
        copy.lastUsed = Date()
        return copy
    }
}
