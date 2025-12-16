//
//  ExportService.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation

/// Service responsible for exporting recordings in various formats
class ExportService {
    
    // MARK: - Export Format Enum
    
    enum ExportFormat {
        case plainText
        case markdown
        case audio
    }
    
    enum ExportError: LocalizedError {
        case audioFileNotFound
        case fileCreationFailed
        case invalidRecording
        
        var errorDescription: String? {
            switch self {
            case .audioFileNotFound:
                return "Audio file not found"
            case .fileCreationFailed:
                return "Failed to create export file"
            case .invalidRecording:
                return "Invalid recording data"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Generate plain text export with transcript and timestamps
    func generatePlainText(for recording: Recording) throws -> URL {
        var content = ""
        
        // Header
        content += "Recording: \(recording.title)\n"
        content += "Date: \(formatDate(recording.date))\n"
        content += "Duration: \(recording.formattedDuration)\n"
        
        if !recording.tags.isEmpty {
            content += "Tags: \(recording.tags.joined(separator: ", "))\n"
        }
        
        content += "\n" + String(repeating: "-", count: 50) + "\n\n"
        
        // Transcript
        content += "TRANSCRIPT\n\n"
        
        for segment in recording.transcript {
            let speakerName = getSpeakerName(for: segment.speakerID, in: recording)
            content += "[\(segment.formattedTimestamp)] \(speakerName): \(segment.text)\n"
        }
        
        // Notes
        if !recording.notes.isEmpty {
            content += "\n" + String(repeating: "-", count: 50) + "\n\n"
            content += "NOTES\n\n"
            
            for note in recording.sortedNotes() {
                if let timestamp = note.formattedTimestamp {
                    content += "[\(timestamp)] \(note.text)\n"
                } else {
                    content += "\(note.text)\n"
                }
            }
        }
        
        // Write to temporary file
        return try writeToTemporaryFile(content: content, filename: "\(recording.title).txt")
    }
    
    /// Generate Markdown export with formatted headings and speaker labels
    func generateMarkdown(for recording: Recording) throws -> URL {
        var content = ""
        
        // Header
        content += "# \(recording.title)\n\n"
        content += "**Date:** \(formatDate(recording.date))  \n"
        content += "**Duration:** \(recording.formattedDuration)  \n"
        
        if !recording.tags.isEmpty {
            content += "**Tags:** \(recording.tags.joined(separator: ", "))  \n"
        }
        
        content += "\n---\n\n"
        
        // Transcript
        content += "## Transcript\n\n"
        
        var currentSpeaker = ""
        for segment in recording.transcript {
            let speakerName = getSpeakerName(for: segment.speakerID, in: recording)
            
            // Add speaker heading if speaker changed
            if speakerName != currentSpeaker {
                currentSpeaker = speakerName
                content += "\n### \(speakerName)\n\n"
            }
            
            content += "`\(segment.formattedTimestamp)` \(segment.text)\n\n"
        }
        
        // Notes
        if !recording.notes.isEmpty {
            content += "---\n\n"
            content += "## Notes\n\n"
            
            for note in recording.sortedNotes() {
                if let timestamp = note.formattedTimestamp {
                    content += "- **[\(timestamp)]** \(note.text)\n"
                } else {
                    content += "- \(note.text)\n"
                }
            }
        }
        
        // Write to temporary file
        return try writeToTemporaryFile(content: content, filename: "\(recording.title).md")
    }
    
    /// Copy audio file for sharing
    func generateAudio(for recording: Recording) throws -> URL {
        // Check if audio file exists
        guard FileManager.default.fileExists(atPath: recording.audioFileURL.path) else {
            throw ExportError.audioFileNotFound
        }
        
        // Create temporary file URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let filename = "\(recording.title).\(RecordingAudioConfig.audioFileExtension)"
        let tempURL = tempDirectory.appendingPathComponent(filename)
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: tempURL)
        
        // Copy audio file to temporary location
        try FileManager.default.copyItem(at: recording.audioFileURL, to: tempURL)
        
        return tempURL
    }
    
    // MARK: - Helper Methods
    
    private func getSpeakerName(for speakerID: String, in recording: Recording) -> String {
        if let speaker = recording.speakers.first(where: { $0.id == speakerID }) {
            return speaker.displayName
        }
        return speakerID
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func writeToTemporaryFile(content: String, filename: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(filename)
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: fileURL)
        
        // Write content to file
        guard let data = content.data(using: .utf8) else {
            throw ExportError.fileCreationFailed
        }
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    /// Clean up temporary export files
    func cleanupTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil
            )
            
            let audioExtension = RecordingAudioConfig.audioFileExtension.lowercased()
            // Remove .txt, .md, and the active audio extension from temp directory
            for url in contents {
                let ext = url.pathExtension.lowercased()
                if ext == "txt" || ext == "md" || ext == audioExtension {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            // Silently fail - cleanup is best effort
        }
    }
}
