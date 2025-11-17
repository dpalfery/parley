//
//  Recording.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation

/// Represents a complete recording with all associated metadata
struct Recording: Identifiable, Codable {
    let id: UUID
    var title: String
    let date: Date
    let duration: TimeInterval
    let audioFileURL: URL
    var transcript: [TranscriptSegment]
    var speakers: [SpeakerProfile]
    var tags: [String]
    var notes: [Note]
    let fileSize: Int64
    var isSynced: Bool
    var lastModified: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        duration: TimeInterval,
        audioFileURL: URL,
        transcript: [TranscriptSegment] = [],
        speakers: [SpeakerProfile] = [],
        tags: [String] = [],
        notes: [Note] = [],
        fileSize: Int64,
        isSynced: Bool = false,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.audioFileURL = audioFileURL
        self.transcript = transcript
        self.speakers = speakers
        self.tags = tags
        self.notes = notes
        self.fileSize = fileSize
        self.isSynced = isSynced
        self.lastModified = lastModified
    }
    
    // MARK: - Computed Properties
    
    /// Formatted duration string (HH:MM:SS or MM:SS)
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Formatted file size string (B, KB, MB, GB)
    var formattedFileSize: String {
        let bytes = Double(fileSize)
        
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytes / (1024 * 1024 * 1024))
        }
    }
    
    /// Searchable content combining title, transcript, and tags
    var searchableContent: String {
        let transcriptText = transcript.map { $0.text }.joined(separator: " ")
        let tagsText = tags.joined(separator: " ")
        return "\(title) \(transcriptText) \(tagsText)".lowercased()
    }
    
    /// Relative date string (Today, Yesterday, or formatted date)
    var relativeDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns notes sorted by timestamp
    func sortedNotes() -> [Note] {
        notes.sorted { (note1, note2) in
            guard let ts1 = note1.timestamp, let ts2 = note2.timestamp else {
                return note1.timestamp != nil
            }
            return ts1 < ts2
        }
    }
    
    /// Returns transcript segments for a specific speaker
    func transcriptSegments(for speakerID: String) -> [TranscriptSegment] {
        transcript.filter { $0.speakerID == speakerID }
    }
    
    /// Returns all unique speaker IDs in the recording
    func uniqueSpeakerIDs() -> [String] {
        Array(Set(transcript.map { $0.speakerID })).sorted()
    }
}

/// Represents a note attached to a recording
struct Note: Identifiable, Codable {
    let id: UUID
    var text: String
    let timestamp: TimeInterval?
    let createdAt: Date
    
    init(id: UUID = UUID(), text: String, timestamp: TimeInterval? = nil, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.createdAt = createdAt
    }
    
    // MARK: - Computed Properties
    
    /// Formatted timestamp string (MM:SS)
    var formattedTimestamp: String? {
        guard let timestamp = timestamp else { return nil }
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
