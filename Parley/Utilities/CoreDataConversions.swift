//
//  CoreDataConversions.swift
//  Parley
//
//  Created on 2025-11-16.
//

import CoreData
import Foundation

// MARK: - RecordingEntity Conversions

extension RecordingEntity {
    /// Converts a Recording model to RecordingEntity
    /// - Parameters:
    ///   - recording: The Recording model to convert
    ///   - context: The managed object context
    /// - Returns: A RecordingEntity instance
    /// - Throws: StorageError if conversion fails
    static func from(recording: Recording, context: NSManagedObjectContext) throws -> RecordingEntity {
        let entity = RecordingEntity(context: context)
        try entity.update(from: recording)
        return entity
    }
    
    /// Updates the entity with data from a Recording model
    /// - Parameter recording: The Recording model to update from
    /// - Throws: StorageError if encoding fails
    func update(from recording: Recording) throws {
        self.id = recording.id
        self.title = recording.title
        self.date = recording.date
        self.duration = recording.duration
        self.audioFileName = recording.audioFileURL.lastPathComponent
        self.fileSize = recording.fileSize
        self.isSynced = recording.isSynced
        self.lastModified = recording.lastModified
        self.searchableContent = recording.searchableContent
        
        // Encode complex types to Data
        let encoder = JSONEncoder()
        
        do {
            self.transcriptData = try encoder.encode(recording.transcript)
            self.speakersData = try encoder.encode(recording.speakers)
            self.tagsData = try encoder.encode(recording.tags)
            self.notesData = try encoder.encode(recording.notes)
        } catch {
            throw StorageError.encodingFailed(underlying: error)
        }
    }
    
    /// Converts the entity to a Recording model
    /// - Returns: A Recording model instance
    /// - Throws: StorageError if decoding fails
    func toRecording() throws -> Recording {
        guard let id = self.id,
              let title = self.title,
              let date = self.date,
              let audioFileName = self.audioFileName,
              let lastModified = self.lastModified else {
            throw StorageError.missingRequiredFields
        }
        
        let decoder = JSONDecoder()
        
        // Decode complex types from Data
        let transcript: [TranscriptSegment]
        let speakers: [SpeakerProfile]
        let tags: [String]
        let notes: [Note]
        
        do {
            transcript = try transcriptData.flatMap { try decoder.decode([TranscriptSegment].self, from: $0) } ?? []
            speakers = try speakersData.flatMap { try decoder.decode([SpeakerProfile].self, from: $0) } ?? []
            tags = try tagsData.flatMap { try decoder.decode([String].self, from: $0) } ?? []
            notes = try notesData.flatMap { try decoder.decode([Note].self, from: $0) } ?? []
        } catch {
            throw StorageError.decodingFailed(underlying: error)
        }
        
        // Construct audio file URL
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileURL = documentsURL
            .appendingPathComponent("Recordings")
            .appendingPathComponent(id.uuidString)
            .appendingPathComponent(audioFileName)
        
        return Recording(
            id: id,
            title: title,
            date: date,
            duration: duration,
            audioFileURL: audioFileURL,
            transcript: transcript,
            speakers: speakers,
            tags: tags,
            notes: notes,
            fileSize: fileSize,
            isSynced: isSynced,
            lastModified: lastModified
        )
    }
}

// MARK: - SpeakerProfileEntity Conversions

extension SpeakerProfileEntity {
    /// Converts a SpeakerProfile model to SpeakerProfileEntity
    /// - Parameters:
    ///   - profile: The SpeakerProfile model to convert
    ///   - context: The managed object context
    /// - Returns: A SpeakerProfileEntity instance
    static func from(profile: SpeakerProfile, context: NSManagedObjectContext) -> SpeakerProfileEntity {
        let entity = SpeakerProfileEntity(context: context)
        entity.update(from: profile)
        return entity
    }
    
    /// Updates the entity with data from a SpeakerProfile model
    /// - Parameter profile: The SpeakerProfile model to update from
    func update(from profile: SpeakerProfile) {
        self.id = profile.id
        self.displayName = profile.displayName
        self.voiceCharacteristics = profile.voiceCharacteristics
        self.createdAt = profile.createdAt
        self.lastUsed = profile.lastUsed
    }
    
    /// Converts the entity to a SpeakerProfile model
    /// - Returns: A SpeakerProfile model instance
    /// - Throws: StorageError if required fields are missing
    func toSpeakerProfile() throws -> SpeakerProfile {
        guard let id = self.id,
              let displayName = self.displayName,
              let voiceCharacteristics = self.voiceCharacteristics,
              let createdAt = self.createdAt,
              let lastUsed = self.lastUsed else {
            throw StorageError.missingRequiredFields
        }
        
        return SpeakerProfile(
            id: id,
            displayName: displayName,
            voiceCharacteristics: voiceCharacteristics,
            createdAt: createdAt,
            lastUsed: lastUsed
        )
    }
}

// MARK: - Batch Conversions

extension Array where Element == RecordingEntity {
    /// Converts an array of RecordingEntity to an array of Recording models
    /// - Returns: Array of Recording models
    /// - Throws: StorageError if any conversion fails
    func toRecordings() throws -> [Recording] {
        try map { try $0.toRecording() }
    }
}

extension Array where Element == SpeakerProfileEntity {
    /// Converts an array of SpeakerProfileEntity to an array of SpeakerProfile models
    /// - Returns: Array of SpeakerProfile models
    /// - Throws: StorageError if any conversion fails
    func toSpeakerProfiles() throws -> [SpeakerProfile] {
        try map { try $0.toSpeakerProfile() }
    }
}
