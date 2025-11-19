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
}
