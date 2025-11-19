//
//  RecordingListViewModel.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation
import Combine

/// View model for the recording list view
@MainActor
class RecordingListViewModel: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var searchQuery = ""
    @Published var selectedTags: Set<String> = []
    @Published var dateRangeStart: Date?
    @Published var dateRangeEnd: Date?
    
    let storageManager: StorageManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    /// Initializes the view model with a storage manager
    /// - Parameter storageManager: The storage manager to use for data operations
    init(storageManager: StorageManagerProtocol) {
        self.storageManager = storageManager
        setupSearchAndFilterObservers()
    }
    
    // MARK: - Setup
    
    /// Sets up observers for search and filter changes
    private func setupSearchAndFilterObservers() {
        // Debounce search query changes
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.applyFilters()
                }
            }
            .store(in: &cancellables)
        
        // React to tag filter changes
        $selectedTags
            .sink { [weak self] _ in
                Task {
                    await self?.applyFilters()
                }
            }
            .store(in: &cancellables)
        
        // React to date range changes
        Publishers.CombineLatest($dateRangeStart, $dateRangeEnd)
            .sink { [weak self] _, _ in
                Task {
                    await self?.applyFilters()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    /// Loads all recordings from storage
    func loadRecordings() async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            recordings = try await storageManager.getAllRecordings(sortedBy: .dateDescending)
        } catch {
            errorMessage = "Failed to load recordings: \(error.localizedDescription)"
            showError = true
            recordings = []
        }
        
        isLoading = false
    }
    
    /// Applies current search and filter criteria
    private func applyFilters() async {
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            var filteredRecordings: [Recording]
            
            // Apply search query
            if !searchQuery.isEmpty {
                filteredRecordings = try await storageManager.searchRecordings(query: searchQuery)
            } else {
                filteredRecordings = try await storageManager.getAllRecordings(sortedBy: .dateDescending)
            }
            
            // Apply tag filter
            if !selectedTags.isEmpty {
                filteredRecordings = filteredRecordings.filter { recording in
                    !Set(recording.tags).isDisjoint(with: selectedTags)
                }
            }
            
            // Apply date range filter
            if let startDate = dateRangeStart, let endDate = dateRangeEnd {
                filteredRecordings = filteredRecordings.filter { recording in
                    recording.date >= startDate && recording.date <= endDate
                }
            } else if let startDate = dateRangeStart {
                filteredRecordings = filteredRecordings.filter { recording in
                    recording.date >= startDate
                }
            } else if let endDate = dateRangeEnd {
                filteredRecordings = filteredRecordings.filter { recording in
                    recording.date <= endDate
                }
            }
            
            recordings = filteredRecordings
        } catch {
            errorMessage = "Failed to filter recordings: \(error.localizedDescription)"
            showError = true
            recordings = []
        }
        
        isLoading = false
    }
    
    // MARK: - Filter Management
    
    /// Toggles a tag in the selected tags set
    /// - Parameter tag: The tag to toggle
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    /// Clears all active filters
    func clearFilters() {
        searchQuery = ""
        selectedTags.removeAll()
        dateRangeStart = nil
        dateRangeEnd = nil
    }
    
    /// Returns all unique tags from all recordings
    var allTags: [String] {
        let tagSet = Set(recordings.flatMap { $0.tags })
        return Array(tagSet).sorted()
    }
    
    /// Returns true if any filters are active
    var hasActiveFilters: Bool {
        !searchQuery.isEmpty || !selectedTags.isEmpty || dateRangeStart != nil || dateRangeEnd != nil
    }
    
    // MARK: - Recording Management
    
    /// Deletes a recording
    /// - Parameters:
    ///   - recording: The recording to delete
    ///   - deleteFromCloud: Whether to also delete from cloud storage
    func deleteRecording(_ recording: Recording, deleteFromCloud: Bool = false) async {
        do {
            try await storageManager.deleteRecording(id: recording.id, deleteFromCloud: deleteFromCloud)
            await loadRecordings()
        } catch {
            errorMessage = "Failed to delete recording: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Cancel all subscriptions
        cancellables.removeAll()
    }
}
