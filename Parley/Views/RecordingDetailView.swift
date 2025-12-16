//
//  RecordingDetailView.swift
//  Parley
//
//  Created on 2025-11-16.
//

import SwiftUI

/// View displaying detailed information about a recording with playback controls
struct RecordingDetailView: View {
    @StateObject private var viewModel: RecordingDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    /// Initializes the recording detail view
    /// - Parameters:
    ///   - recordingID: The UUID of the recording to display
    ///   - storageManager: The storage manager to use
    init(recordingID: UUID, storageManager: StorageManagerProtocol) {
        _viewModel = StateObject(wrappedValue: RecordingDetailViewModel(
            recordingID: recordingID,
            storageManager: storageManager
        ))
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading recording...")
            } else if let recording = viewModel.recording {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header section
                        headerSection(recording: recording)
                        
                        Divider()
                        
                        // Playback controls
                        playbackControlsSection
                        
                        Divider()
                        
                        // Transcript section
                        transcriptSection(recording: recording)
                        
                        Divider()
                        
                        // Notes section
                        notesSection(recording: recording)
                        
                        Divider()
                        
                        // Tags section
                        tagsSection(recording: recording)
                    }
                    .padding()
                }
            } else {
                Text("Recording not found")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(viewModel.recording?.title ?? "Recording")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.recording != nil {
                    HStack(spacing: 16) {
                        exportButton
                        editButton
                    }
                }
            }
        }
        .task {
            await viewModel.loadRecording()
            await viewModel.loadAvailableTags()
        }
        .sheet(isPresented: $viewModel.showAddNoteSheet) {
            AddNoteSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAddTagSheet) {
            AddTagSheet(viewModel: viewModel)
        }
        .confirmationDialog("Export Recording", isPresented: $viewModel.showExportSheet) {
            Button("Plain Text (.txt)") {
                viewModel.exportRecording(format: .plainText)
            }
            
            Button("Markdown (.md)") {
                viewModel.exportRecording(format: .markdown)
            }
            
            Button("Audio File (.\(RecordingAudioConfig.audioFileExtension))") {
                viewModel.exportRecording(format: .audio)
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose export format")
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let shareURL = viewModel.shareURL {
                ShareSheet(items: [shareURL]) {
                    viewModel.cleanupExportFiles()
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private func headerSection(recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recording.title)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                Label(recording.relativeDateString, systemImage: "calendar")
                Label(recording.formattedDuration, systemImage: "clock")
                Label(recording.formattedFileSize, systemImage: "doc")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            // Speakers
            if !recording.speakers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speakers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        ForEach(recording.speakers) { speaker in
                            Text(speaker.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.tagBackground)
                                .foregroundColor(.tagText)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Playback Controls Section
    
    private var playbackControlsSection: some View {
        VStack(spacing: 16) {
            // Progress slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { viewModel.currentTime },
                        set: { viewModel.seek(to: $0) }
                    ),
                    in: 0...(viewModel.recording?.duration ?? 0.0)
                )
                .accessibilityLabel("Playback position")
                .accessibilityValue("\(viewModel.formattedCurrentTime) of \(viewModel.formattedDuration)")
                
                HStack {
                    Text(viewModel.formattedCurrentTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(viewModel.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Playback buttons
            HStack(spacing: 40) {
                Button(action: viewModel.skipBackward) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                }
                .accessibilityLabel("Skip backward 15 seconds")
                .accessibilityHint("Double tap to skip backward 15 seconds")
                
                Button(action: viewModel.togglePlayPause) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }
                .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
                .accessibilityHint(viewModel.isPlaying ? "Double tap to pause playback" : "Double tap to play recording")
                
                Button(action: viewModel.skipForward) {
                    Image(systemName: "goforward.15")
                        .font(.title)
                }
                .accessibilityLabel("Skip forward 15 seconds")
                .accessibilityHint("Double tap to skip forward 15 seconds")
            }
            .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Transcript Section
    
    private func transcriptSection(recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.isEditMode {
                    Text("Editing")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if recording.transcript.isEmpty {
                Text("No transcript available")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(viewModel.isEditMode ? viewModel.editedTranscript : recording.transcript) { segment in
                            TranscriptSegmentView(
                                segment: segment,
                                isHighlighted: viewModel.currentSegmentID == segment.id,
                                isEditMode: viewModel.isEditMode,
                                speakerName: viewModel.getSpeakerName(for: segment.speakerID),
                                onTextChange: { newText in
                                    viewModel.updateSegmentText(segment.id, newText: newText)
                                },
                                onSpeakerChange: { newSpeakerID in
                                    viewModel.updateSegmentSpeaker(segment.id, newSpeakerID: newSpeakerID)
                                },
                                onTap: {
                                    viewModel.seek(to: segment.timestamp)
                                }
                            )
                            .id(segment.id)
                        }
                    }
                    .onChange(of: viewModel.currentSegmentID) { newSegmentID in
                        if let segmentID = newSegmentID {
                            withAnimation {
                                proxy.scrollTo(segmentID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Notes Section
    
    private func notesSection(recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.showAddNoteSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .accessibilityLabel("Add note")
                .accessibilityHint("Double tap to add a new note")
            }
            
            if recording.notes.isEmpty {
                Text("No notes")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recording.sortedNotes()) { note in
                        NoteRowView(
                            note: note,
                            onEdit: { viewModel.editingNote = note },
                            onDelete: { viewModel.deleteNote(note.id) }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Tags Section
    
    private func tagsSection(recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tags")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    viewModel.showAddTagSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .accessibilityLabel("Add tag")
                .accessibilityHint("Double tap to add a new tag")
            }
            
            if recording.tags.isEmpty {
                Text("No tags")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(recording.tags, id: \.self) { tag in
                        TagChip(text: tag) {
                            viewModel.removeTag(tag)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Export Button
    
    private var exportButton: some View {
        Button(action: {
            viewModel.showExportSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Export recording")
        .accessibilityHint("Double tap to export recording in different formats")
    }
    
    // MARK: - Edit Button
    
    private var editButton: some View {
        Button(action: viewModel.toggleEditMode) {
            Text(viewModel.isEditMode ? "Save" : "Edit")
        }
        .accessibilityLabel(viewModel.isEditMode ? "Save transcript edits" : "Edit transcript")
        .accessibilityHint(viewModel.isEditMode ? "Double tap to save changes to transcript" : "Double tap to edit transcript")
    }
}

// MARK: - Transcript Segment View

struct TranscriptSegmentView: View {
    let segment: TranscriptSegment
    let isHighlighted: Bool
    let isEditMode: Bool
    let speakerName: String
    let onTextChange: (String) -> Void
    let onSpeakerChange: (String) -> Void
    let onTap: () -> Void
    
    @State private var editedText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(speakerName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.speakerLabel)
                
                Text(segment.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if segment.isLowConfidence {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.lowConfidence)
                }
                
                if segment.isEdited {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isEditMode {
                TextEditor(text: $editedText)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(Color.inputBackground)
                    .cornerRadius(8)
                    .focused($isFocused)
                    .onChange(of: editedText) { newValue in
                        onTextChange(newValue)
                    }
                    .accessibilityLabel("Edit transcript text")
            } else {
                Text(segment.text)
                    .font(.body)
                    .onTapGesture {
                        onTap()
                    }
            }
        }
        .padding(12)
        .background(isHighlighted ? Color.transcriptHighlight : Color.clear)
        .cornerRadius(8)
        .onAppear {
            editedText = segment.text
        }
        .accessibilityElement(children: isEditMode ? .contain : .combine)
        .accessibilityLabel(isEditMode ? "" : "\(speakerName) at \(segment.formattedTimestamp)\(segment.isLowConfidence ? ", low confidence" : "")\(segment.isEdited ? ", edited" : ""): \(segment.text)")
        .accessibilityHint(isEditMode ? "" : "Double tap to jump to this point in the recording")
    }
}

// MARK: - Note Row View

struct NoteRowView: View {
    let note: Note
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let timestamp = note.formattedTimestamp {
                    Text(timestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Delete note")
                .accessibilityHint("Double tap to delete this note")
            }
            
            Text(note.text)
                .font(.body)
        }
        .padding(12)
        .background(Color.inputBackground)
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Note\(note.formattedTimestamp != nil ? " at \(note.formattedTimestamp!)" : ""): \(note.text)")
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .accessibilityLabel("Remove tag \(text)")
            .accessibilityHint("Double tap to remove this tag")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.tagBackground)
        .foregroundColor(.tagText)
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Add Note Sheet

struct AddNoteSheet: View {
    @ObservedObject var viewModel: RecordingDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $noteText)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color.inputBackground)
                    .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addNote(text: noteText)
                        dismiss()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Tag Sheet

struct AddTagSheet: View {
    @ObservedObject var viewModel: RecordingDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Enter tag", text: $viewModel.tagInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                
                if !viewModel.availableTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Existing Tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                Button(action: {
                                    viewModel.addTag(tag)
                                    dismiss()
                                }) {
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.tagBackground)
                                        .foregroundColor(.tagText)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addTag(viewModel.tagInput)
                        dismiss()
                    }
                    .disabled(viewModel.tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    NavigationStack {
        RecordingDetailView(
            recordingID: UUID(),
            storageManager: StorageManager()
        )
    }
}
