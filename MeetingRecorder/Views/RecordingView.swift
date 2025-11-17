//
//  RecordingView.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

/// Main recording view with controls and real-time feedback
struct RecordingView: View {
    
    @StateObject private var viewModel: RecordingViewModel
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    
    init(
        recordingService: RecordingServiceProtocol,
        transcriptionService: TranscriptionServiceProtocol,
        speakerService: SpeakerServiceProtocol,
        storageManager: StorageManager
    ) {
        _viewModel = StateObject(wrappedValue: RecordingViewModel(
            recordingService: recordingService,
            transcriptionService: transcriptionService,
            stateRestorationManager: AppEnvironment.shared.stateRestorationManager
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Recording state indicator
                recordingStateIndicator
                
                // Duration display
                durationDisplay
                
                // Audio level visualization
                AudioLevelMeterView(audioLevel: viewModel.audioLevel)
                    .frame(height: 100)
                    .padding(.horizontal)
                    .accessibilityLabel("Audio level")
                    .accessibilityValue("\(Int(viewModel.audioLevel * 100)) percent")
                
                // Real-time transcription display
                transcriptionView
                
                Spacer()
                
                // Recording controls
                recordingControls
                
                // Notes button
                notesButton
            }
            .padding()
            .navigationTitle("Recording")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $viewModel.showNotesSheet) {
                NotesInputView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - View Components
    
    private var recordingStateIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            
            Text(stateText)
                .font(.headline)
                .foregroundColor(stateColor)
        }
        .padding(.top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recording state: \(stateText)")
    }
    
    private var durationDisplay: some View {
        Text(viewModel.formattedDuration)
            .font(.system(size: 48, weight: .bold, design: .monospaced))
            .foregroundColor(.primary)
            .accessibilityLabel("Recording duration: \(viewModel.formattedDuration)")
    }
    
    private var transcriptionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.transcriptSegments) { segment in
                            TranscriptSegmentView(segment: segment)
                                .id(segment.id)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                .background(Color.inputBackground)
                .cornerRadius(12)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Live transcript")
                .onChange(of: viewModel.transcriptSegments.count) { _ in
                    // Auto-scroll to latest segment
                    if let lastSegment = viewModel.transcriptSegments.last {
                        withAnimation {
                            proxy.scrollTo(lastSegment.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private var recordingControls: some View {
        HStack(spacing: 32) {
            // Pause/Resume button
            if viewModel.isRecordingActive {
                Button(action: {
                    if viewModel.canPause {
                        viewModel.pauseRecording()
                    } else if viewModel.canResume {
                        viewModel.resumeRecording()
                    }
                }) {
                    Image(systemName: viewModel.recordingState == .paused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                .disabled(!viewModel.canPause && !viewModel.canResume)
                .accessibilityLabel(viewModel.recordingState == .paused ? "Resume recording" : "Pause recording")
                .accessibilityHint(viewModel.recordingState == .paused ? "Double tap to resume recording" : "Double tap to pause recording")
            }
            
            // Record/Stop button
            Button(action: {
                if viewModel.canRecord {
                    viewModel.startRecording()
                } else if viewModel.canStop {
                    Task {
                        if let recording = await viewModel.stopRecording() {
                            // Recording saved - dismiss view or navigate
                            dismiss()
                        }
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.canRecord ? Color.red : Color.gray)
                        .frame(width: 80, height: 80)
                    
                    if viewModel.canRecord {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    }
                }
            }
            .disabled(viewModel.recordingState == .processing)
            .accessibilityLabel(viewModel.canRecord ? "Start recording" : "Stop recording")
            .accessibilityHint(viewModel.canRecord ? "Double tap to start recording" : "Double tap to stop and save recording")
            
            // Cancel button (only when recording)
            if viewModel.isRecordingActive {
                Button(action: {
                    viewModel.cancelRecording()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Cancel recording")
                .accessibilityHint("Double tap to discard recording without saving")
            }
        }
        .padding(.bottom)
    }
    
    private var notesButton: some View {
        Button(action: {
            viewModel.showNotesSheet = true
        }) {
            HStack {
                Image(systemName: "note.text")
                Text("Notes")
                if viewModel.notesCount > 0 {
                    Text("(\(viewModel.notesCount))")
                        .foregroundColor(.secondary)
                }
            }
            .font(.headline)
            .foregroundColor(.appAccent)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.inputBackground)
            .cornerRadius(12)
        }
        .disabled(!viewModel.isRecordingActive && viewModel.recordingState != .idle)
        .accessibilityLabel(viewModel.notesCount > 0 ? "Notes, \(viewModel.notesCount) notes added" : "Add note")
        .accessibilityHint("Double tap to add a note to this recording")
    }
    
    // MARK: - Helper Properties
    
    private var stateColor: Color {
        switch viewModel.recordingState {
        case .idle:
            return .recordingIdle
        case .recording:
            return .recordingActive
        case .paused:
            return .recordingPaused
        case .processing:
            return .recordingProcessing
        }
    }
    
    private var stateText: String {
        switch viewModel.recordingState {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording"
        case .paused:
            return "Paused"
        case .processing:
            return "Processing"
        }
    }
}

// MARK: - Supporting Views

/// View for displaying a single transcript segment
struct TranscriptSegmentView: View {
    let segment: TranscriptSegment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(segment.speakerID)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.speakerLabel)
                
                Text(segment.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if segment.isLowConfidence {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.lowConfidence)
                        .accessibilityLabel("Low confidence")
                }
            }
            
            Text(segment.text)
                .font(.body)
                .foregroundColor(segment.isLowConfidence ? .secondaryText : .primaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(segment.speakerID) at \(segment.formattedTimestamp)\(segment.isLowConfidence ? ", low confidence" : ""): \(segment.text)")
    }
}

/// View for notes input during recording
struct NotesInputView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Enter note...", text: $noteText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(5...10)
                    .padding()
                
                Spacer()
            }
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
                        if !noteText.isEmpty {
                            viewModel.addNote(text: noteText)
                            dismiss()
                        }
                    }
                    .disabled(noteText.isEmpty)
                }
            }
        }
    }
}

#Preview {
    RecordingView(
        recordingService: RecordingService(),
        transcriptionService: TranscriptionService()
    )
}
