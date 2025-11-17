//
//  RecordingListView.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

/// Main view displaying the list of recordings
struct RecordingListView: View {
    @StateObject private var viewModel: RecordingListViewModel
    @State private var showingRecordingView = false
    @State private var showingFilterSheet = false
    @State private var showingSettings = false
    
    /// Initializes the recording list view
    /// - Parameter storageManager: The storage manager to use
    init(storageManager: StorageManagerProtocol) {
        _viewModel = StateObject(wrappedValue: RecordingListViewModel(storageManager: storageManager))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.recordings.isEmpty {
                    ProgressView("Loading recordings...")
                } else if viewModel.recordings.isEmpty {
                    emptyStateView
                } else {
                    recordingsList
                }
            }
            .navigationTitle("Recordings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    settingsButton
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    filterButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    recordButton
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Search recordings")
            .sheet(isPresented: $showingRecordingView) {
                RecordingView(
                    recordingService: RecordingService(),
                    transcriptionService: TranscriptionService()
                )
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(
                    storageManager: viewModel.storageManager,
                    cloudSyncService: CloudSyncService(storageManager: viewModel.storageManager)
                )
            }
            .task {
                await viewModel.loadRecordings()
            }
            .refreshable {
                await viewModel.loadRecordings()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// List of recordings
    private var recordingsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.hasActiveFilters {
                    activeFiltersView
                }
                
                ForEach(viewModel.recordings) { recording in
                    NavigationLink(destination: RecordingDetailView(recordingID: recording.id, storageManager: viewModel.storageManager)) {
                        RecordingRowView(recording: recording)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
    
    /// Empty state view when no recordings exist
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Recordings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the record button to start your first recording")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    /// Settings button
    private var settingsButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gear")
        }
        .accessibilityLabel("Settings")
        .accessibilityHint("Double tap to open settings")
    }
    
    /// Filter button
    private var filterButton: some View {
        Button(action: {
            showingFilterSheet = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                if viewModel.hasActiveFilters {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel(viewModel.hasActiveFilters ? "Filter recordings, filters active" : "Filter recordings")
        .accessibilityHint("Double tap to filter recordings by tags or date")
    }
    
    /// Record button
    private var recordButton: some View {
        Button(action: {
            showingRecordingView = true
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
        }
        .accessibilityLabel("New recording")
        .accessibilityHint("Double tap to start a new recording")
    }
    
    /// Active filters indicator view
    private var activeFiltersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active Filters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Clear All") {
                    viewModel.clearFilters()
                }
                .font(.caption)
                .accessibilityLabel("Clear all filters")
                .accessibilityHint("Double tap to remove all active filters")
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !viewModel.searchQuery.isEmpty {
                        FilterChip(text: "Search: \(viewModel.searchQuery)") {
                            viewModel.searchQuery = ""
                        }
                    }
                    
                    ForEach(Array(viewModel.selectedTags), id: \.self) { tag in
                        FilterChip(text: tag) {
                            viewModel.toggleTag(tag)
                        }
                    }
                    
                    if viewModel.dateRangeStart != nil || viewModel.dateRangeEnd != nil {
                        FilterChip(text: "Date Range") {
                            viewModel.dateRangeStart = nil
                            viewModel.dateRangeEnd = nil
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(8)
    }
}

/// Filter chip view for displaying active filters
struct FilterChip: View {
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.filterChipBackground)
        .foregroundColor(.filterChipText)
        .cornerRadius(16)
    }
}

#Preview {
    RecordingListView(storageManager: StorageManager())
}
