//
//  RecordingRowView.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

/// Row view for displaying a recording in the list
struct RecordingRowView: View {
    let recording: Recording
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Recording icon
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.appAccent)
                .accessibilityHidden(true)
            
            // Recording details
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(recording.title)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                    .lineLimit(2)
                
                // Date and duration
                HStack(spacing: 8) {
                    Text(recording.relativeDateString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    
                    Text(recording.formattedDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Tags
                if !recording.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(recording.tags, id: \.self) { tag in
                                TagView(tag: tag)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            // Sync status icon
            VStack(spacing: 4) {
                syncStatusIcon
                
                Text(recording.formattedFileSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    // MARK: - Subviews
    
    /// Sync status icon based on recording sync state
    @ViewBuilder
    private var syncStatusIcon: some View {
        if recording.isSynced {
            Image(systemName: "checkmark.icloud.fill")
                .font(.caption)
                .foregroundColor(.syncedStatus)
        } else {
            Image(systemName: "icloud.slash")
                .font(.caption)
                .foregroundColor(.notSyncedStatus)
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityDescription: String {
        var description = "Recording: \(recording.title), "
        description += "\(recording.relativeDateString), "
        description += "duration \(recording.formattedDuration), "
        description += "size \(recording.formattedFileSize)"
        
        if !recording.tags.isEmpty {
            description += ", tags: \(recording.tags.joined(separator: ", "))"
        }
        
        description += recording.isSynced ? ", synced to iCloud" : ", not synced"
        
        return description
    }
}

/// Tag view for displaying a single tag
struct TagView: View {
    let tag: String
    
    var body: some View {
        Text(tag)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.tagBackground)
            .foregroundColor(.tagText)
            .cornerRadius(6)
    }
}

#Preview {
    VStack(spacing: 12) {
        RecordingRowView(recording: Recording(
            title: "Team Standup Meeting",
            date: Date(),
            duration: 1845,
            audioFileURL: URL(fileURLWithPath: "/tmp/audio.m4a"),
            tags: ["standup", "team-alpha"],
            fileSize: 15728640,
            isSynced: true
        ))
        
        RecordingRowView(recording: Recording(
            title: "Client Call - Project Discussion",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            duration: 3600,
            audioFileURL: URL(fileURLWithPath: "/tmp/audio.m4a"),
            tags: ["client", "project"],
            fileSize: 32505856,
            isSynced: false
        ))
        
        RecordingRowView(recording: Recording(
            title: "Quick Note",
            date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            duration: 120,
            audioFileURL: URL(fileURLWithPath: "/tmp/audio.m4a"),
            fileSize: 1048576,
            isSynced: true
        ))
    }
    .padding()
}
