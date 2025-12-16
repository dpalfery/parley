//
//  FilterView.swift
//  Parley
//
//  Created on 2025-11-16.
//

import SwiftUI

/// View for filtering recordings by tags and date range
struct FilterView: View {
    @ObservedObject var viewModel: RecordingListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Tag filter section
                Section {
                    if viewModel.allTags.isEmpty {
                        Text("No tags available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.allTags, id: \.self) { tag in
                            TagFilterRow(
                                tag: tag,
                                isSelected: viewModel.selectedTags.contains(tag)
                            ) {
                                viewModel.toggleTag(tag)
                            }
                        }
                    }
                } header: {
                    Text("Filter by Tags")
                } footer: {
                    if !viewModel.selectedTags.isEmpty {
                        Text("\(viewModel.selectedTags.count) tag(s) selected")
                    }
                }
                
                // Date range filter section
                Section {
                    DatePicker(
                        "Start Date",
                        selection: Binding(
                            get: { viewModel.dateRangeStart ?? Date() },
                            set: { viewModel.dateRangeStart = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    Toggle("Use Start Date", isOn: Binding(
                        get: { viewModel.dateRangeStart != nil },
                        set: { isOn in
                            if isOn {
                                viewModel.dateRangeStart = Date()
                            } else {
                                viewModel.dateRangeStart = nil
                            }
                        }
                    ))
                    
                    DatePicker(
                        "End Date",
                        selection: Binding(
                            get: { viewModel.dateRangeEnd ?? Date() },
                            set: { viewModel.dateRangeEnd = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    Toggle("Use End Date", isOn: Binding(
                        get: { viewModel.dateRangeEnd != nil },
                        set: { isOn in
                            if isOn {
                                viewModel.dateRangeEnd = Date()
                            } else {
                                viewModel.dateRangeEnd = nil
                            }
                        }
                    ))
                } header: {
                    Text("Filter by Date Range")
                } footer: {
                    if viewModel.dateRangeStart != nil || viewModel.dateRangeEnd != nil {
                        Text("Date range filter is active")
                    }
                }
                
                // Clear filters section
                if viewModel.hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            viewModel.clearFilters()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear All Filters")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Row view for a tag filter option
struct TagFilterRow: View {
    let tag: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                TagView(tag: tag)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FilterView(viewModel: RecordingListViewModel(storageManager: StorageManager()))
}
