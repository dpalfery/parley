//
//  SpeakerService.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import AVFoundation
import CoreData
import os.log

/// Implementation of SpeakerServiceProtocol for speaker diarization and identification
final class SpeakerService: SpeakerServiceProtocol {
    
    // MARK: - Private Properties
    
    private let persistenceController: PersistenceController
    private let logger = Logger(subsystem: "com.meetingrecorder.app", category: "SpeakerService")
    
    // Voice Activity Detection parameters
    private let energyThreshold: Float = -40.0  // dB threshold for voice activity
    private let minSpeechDuration: TimeInterval = 0.5  // Minimum duration for speech segment
    private let minPauseDuration: TimeInterval = 0.8  // Minimum pause to detect speaker change
    private let analysisWindowSize: Int = 4096  // Samples per analysis window
    
    // Speaker tracking
    private var currentSpeakerID: String?
    private var speakerCounter: Int = 0
    private var speakerSegments: [SpeakerSegment] = []
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - SpeakerServiceProtocol Implementation
    
    func detectSpeakers(audioURL: URL) async throws -> [SpeakerSegment] {
        logger.info("Starting speaker detection for audio file: \(audioURL.lastPathComponent)")
        
        // Reset state
        speakerSegments = []
        speakerCounter = 0
        currentSpeakerID = nil
        
        // Load audio file
        guard let audioFile = try? AVAudioFile(forReading: audioURL) else {
            logger.error("Failed to load audio file for speaker detection")
            throw SpeakerError.detectionFailed
        }
        
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            logger.error("Failed to create audio buffer")
            throw SpeakerError.detectionFailed
        }
        
        do {
            try audioFile.read(into: buffer)
        } catch {
            logger.error("Failed to read audio file: \(error.localizedDescription)")
            throw SpeakerError.detectionFailed
        }
        
        // Perform voice activity detection and speaker change detection
        try await performVoiceActivityDetection(buffer: buffer, sampleRate: format.sampleRate)
        
        logger.info("Speaker detection completed. Found \(self.speakerSegments.count) segments")
        
        return speakerSegments
    }
    
    func assignSpeakerToSegment(segmentID: UUID, speakerID: String) async throws {
        logger.info("Assigning speaker \(speakerID) to segment \(segmentID)")
        
        // This method would be used to update transcript segments with speaker assignments
        // In a full implementation, this would update the stored recording's transcript
        // For now, we'll validate the speaker exists
        
        guard await getSpeakerProfile(speakerID: speakerID) != nil else {
            logger.error("Speaker profile not found: \(speakerID)")
            throw SpeakerError.profileNotFound
        }
        
        // Update lastUsed timestamp for the speaker
        try await updateSpeakerLastUsed(speakerID: speakerID)
        
        logger.info("Successfully assigned speaker to segment")
    }
    
    func updateSpeakerName(speakerID: String, name: String) async throws {
        logger.info("Updating speaker name: \(speakerID) -> \(name)")
        
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            // Fetch speaker profile entity
            let fetchRequest: NSFetchRequest<SpeakerProfileEntity> = SpeakerProfileEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", speakerID)
            
            guard let entity = try context.fetch(fetchRequest).first else {
                self.logger.error("Speaker profile not found: \(speakerID)")
                throw SpeakerError.profileNotFound
            }
            
            // Update display name
            entity.displayName = name
            entity.lastUsed = Date()
            
            // Save context
            if context.hasChanges {
                try context.save()
            }
            
            self.logger.info("Speaker name updated successfully")
        }
    }
    
    func getSpeakerProfile(speakerID: String) async -> SpeakerProfile? {
        let context = persistenceController.newBackgroundContext()
        
        return await context.perform {
            // Fetch speaker profile entity
            let fetchRequest: NSFetchRequest<SpeakerProfileEntity> = SpeakerProfileEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", speakerID)
            
            guard let entity = try? context.fetch(fetchRequest).first else {
                return nil
            }
            
            // Convert to model
            return SpeakerProfile(
                id: entity.id ?? "",
                displayName: entity.displayName ?? "Unknown Speaker",
                voiceCharacteristics: entity.voiceCharacteristics ?? Data(),
                createdAt: entity.createdAt ?? Date(),
                lastUsed: entity.lastUsed ?? Date()
            )
        }
    }
    
    // MARK: - Voice Activity Detection
    
    /// Performs energy-based voice activity detection and speaker change detection
    private func performVoiceActivityDetection(buffer: AVAudioPCMBuffer, sampleRate: Double) async throws {
        guard let channelData = buffer.floatChannelData?[0] else {
            throw SpeakerError.detectionFailed
        }
        
        let frameLength = Int(buffer.frameLength)
        let windowSize = analysisWindowSize
        let hopSize = windowSize / 2  // 50% overlap
        
        var currentSegmentStart: TimeInterval?
        var lastSpeechTime: TimeInterval = 0.0
        var previousEnergy: Float = 0.0
        
        // Analyze audio in windows
        var windowIndex = 0
        while windowIndex * hopSize < frameLength {
            let startSample = windowIndex * hopSize
            let endSample = min(startSample + windowSize, frameLength)
            let windowLength = endSample - startSample
            
            // Calculate energy for this window
            var energy: Float = 0.0
            for i in startSample..<endSample {
                let sample = channelData[i]
                energy += sample * sample
            }
            energy = energy / Float(windowLength)
            
            // Convert to dB
            let energyDB = 10 * log10(max(energy, 1e-10))
            
            // Calculate timestamp for this window
            let timestamp = Double(startSample) / sampleRate
            
            // Voice activity detection
            if energyDB > energyThreshold {
                // Speech detected
                if currentSegmentStart == nil {
                    // Start new speech segment
                    currentSegmentStart = timestamp
                    
                    // Check if this is a speaker change (significant pause)
                    if lastSpeechTime > 0 && (timestamp - lastSpeechTime) > minPauseDuration {
                        // Detect speaker change based on energy shift
                        let energyDifference = abs(energyDB - previousEnergy)
                        
                        if energyDifference > 10.0 {  // Significant energy change
                            // Likely a new speaker
                            assignNewSpeaker()
                        }
                    } else if currentSpeakerID == nil {
                        // First speaker
                        assignNewSpeaker()
                    }
                }
                
                lastSpeechTime = timestamp
                previousEnergy = energyDB
                
            } else {
                // Silence detected
                if let segmentStart = currentSegmentStart {
                    let segmentDuration = timestamp - segmentStart
                    
                    // Check if segment is long enough
                    if segmentDuration >= minSpeechDuration {
                        // Create speaker segment
                        if let speakerID = currentSpeakerID {
                            let segment = SpeakerSegment(
                                speakerID: speakerID,
                                startTime: segmentStart,
                                endTime: timestamp
                            )
                            speakerSegments.append(segment)
                        }
                    }
                    
                    currentSegmentStart = nil
                }
            }
            
            windowIndex += 1
        }
        
        // Handle final segment if still active
        if let segmentStart = currentSegmentStart {
            let finalTimestamp = Double(frameLength) / sampleRate
            let segmentDuration = finalTimestamp - segmentStart
            
            if segmentDuration >= minSpeechDuration, let speakerID = currentSpeakerID {
                let segment = SpeakerSegment(
                    speakerID: speakerID,
                    startTime: segmentStart,
                    endTime: finalTimestamp
                )
                speakerSegments.append(segment)
            }
        }
        
        // Create speaker profiles for detected speakers
        try await createSpeakerProfiles()
    }
    
    /// Assigns a new speaker ID for the current segment
    private func assignNewSpeaker() {
        speakerCounter += 1
        currentSpeakerID = "speaker-\(speakerCounter)"
        logger.info("Detected new speaker: \(self.currentSpeakerID ?? "unknown")")
    }
    
    // MARK: - Speaker Profile Management
    
    /// Creates speaker profiles for all detected speakers
    private func createSpeakerProfiles() async throws {
        let uniqueSpeakerIDs = Set(speakerSegments.map { $0.speakerID })
        
        for speakerID in uniqueSpeakerIDs {
            // Check if profile already exists
            if await getSpeakerProfile(speakerID: speakerID) == nil {
                try await createSpeakerProfile(speakerID: speakerID)
            }
        }
    }
    
    /// Creates a new speaker profile
    private func createSpeakerProfile(speakerID: String) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            let entity = SpeakerProfileEntity(context: context)
            entity.id = speakerID
            
            // Generate display name based on speaker number
            let speakerNumber = speakerID.replacingOccurrences(of: "speaker-", with: "")
            entity.displayName = "Speaker \(speakerNumber)"
            
            // Store basic voice characteristics (placeholder for MVP)
            entity.voiceCharacteristics = Data()
            
            entity.createdAt = Date()
            entity.lastUsed = Date()
            
            // Save context
            if context.hasChanges {
                try context.save()
            }
            
            self.logger.info("Created speaker profile: \(speakerID)")
        }
    }
    
    /// Updates the lastUsed timestamp for a speaker profile
    private func updateSpeakerLastUsed(speakerID: String) async throws {
        let context = persistenceController.newBackgroundContext()
        
        try await context.perform {
            let fetchRequest: NSFetchRequest<SpeakerProfileEntity> = SpeakerProfileEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", speakerID)
            
            guard let entity = try context.fetch(fetchRequest).first else {
                return
            }
            
            entity.lastUsed = Date()
            
            if context.hasChanges {
                try context.save()
            }
        }
    }

    // MARK: - Speaker-Transcript Association
    
    /// Associates detected speaker segments with transcript segments based on timestamps
    /// - Parameters:
    ///   - transcriptSegments: Array of transcript segments to update
    ///   - speakerSegments: Array of detected speaker segments
    /// - Returns: Updated transcript segments with speaker IDs assigned
    func associateSpeakersWithTranscript(
        transcriptSegments: [TranscriptSegment],
        speakerSegments: [SpeakerSegment]
    ) -> [TranscriptSegment] {
        logger.info("Associating \(speakerSegments.count) speaker segments with \(transcriptSegments.count) transcript segments")
        
        var updatedSegments: [TranscriptSegment] = []
        
        for transcriptSegment in transcriptSegments {
            // Find the speaker segment that contains this transcript segment's timestamp
            let matchingSpeaker = speakerSegments.first { speakerSegment in
                speakerSegment.contains(timestamp: transcriptSegment.timestamp)
            }
            
            if let speaker = matchingSpeaker {
                // Update transcript segment with speaker ID
                let updatedSegment = transcriptSegment.withUpdatedSpeaker(speaker.speakerID)
                updatedSegments.append(updatedSegment)
            } else {
                // No matching speaker found, keep original
                updatedSegments.append(transcriptSegment)
            }
        }
        
        logger.info("Successfully associated speakers with transcript segments")
        
        return updatedSegments
    }
    
    /// Publishes speaker change events for UI indicators
    /// - Parameter speakerSegments: Array of speaker segments
    /// - Returns: Array of timestamps where speaker changes occur
    func getSpeakerChangeTimestamps(speakerSegments: [SpeakerSegment]) -> [TimeInterval] {
        var changeTimestamps: [TimeInterval] = []
        
        // Sort segments by start time
        let sortedSegments = speakerSegments.sorted { $0.startTime < $1.startTime }
        
        // Track speaker changes
        var previousSpeakerID: String?
        
        for segment in sortedSegments {
            if let previous = previousSpeakerID, previous != segment.speakerID {
                // Speaker changed
                changeTimestamps.append(segment.startTime)
            }
            previousSpeakerID = segment.speakerID
        }
        
        return changeTimestamps
    }
}
