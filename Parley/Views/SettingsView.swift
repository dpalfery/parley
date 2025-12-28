//
//  SettingsView.swift
//  Parley
//
//  Created on 2025-11-16.
//

import SwiftUI

/// Settings view for configuring app preferences
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    var showDoneButton: Bool
    
    init(storageManager: StorageManagerProtocol, cloudSyncService: CloudSyncServiceProtocol, showDoneButton: Bool = false) {
        self.showDoneButton = showDoneButton
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            storageManager: storageManager,
            cloudSyncService: cloudSyncService
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Audio Settings Section
                Section {
                    Picker("Audio Quality", selection: $viewModel.selectedAudioQuality) {
                        ForEach(AudioQuality.allCases) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .onChange(of: viewModel.selectedAudioQuality) { oldValue, newValue in
                        viewModel.updateAudioQuality(newValue)
                    }
                } header: {
                    Text("Audio")
                } footer: {
                    Text("Higher quality recordings use more storage space")
                }
                
                // iCloud Sync Section
                Section {
                    Toggle("iCloud Sync", isOn: $viewModel.iCloudSyncEnabled)
                        .onChange(of: viewModel.iCloudSyncEnabled) { oldValue, newValue in
                            Task {
                                await viewModel.toggleiCloudSync()
                            }
                        }
                        .disabled(viewModel.isLoading)
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Automatically backup recordings to iCloud Drive")
                }
                
                // Storage Section
                Section {
                    if let usage = viewModel.storageUsage {
                        HStack {
                            Text("Total Storage Used")
                            Spacer()
                            Text(usage.formattedTotalSize)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Number of Recordings")
                            Spacer()
                            Text("\(usage.recordingCount)")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("View Storage Breakdown") {
                            viewModel.showStorageBreakdown()
                        }
                    } else if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Unable to load storage information")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Storage")
                }
                
                // Auto-Cleanup Section
                Section {
                    Picker("Auto-Cleanup Threshold", selection: $viewModel.autoCleanupThreshold) {
                        ForEach(CleanupThreshold.allCases) { threshold in
                            Text(threshold.displayName).tag(threshold)
                        }
                    }
                    .onChange(of: viewModel.autoCleanupThreshold) { oldValue, newValue in
                        viewModel.updateCleanupThreshold(newValue)
                    }
                    
                    Button("Clean Up Now") {
                        viewModel.showCleanupConfirmation()
                    }
                    .disabled(viewModel.autoCleanupThreshold == .never)
                } header: {
                    Text("Storage Management")
                } footer: {
                    if viewModel.autoCleanupThreshold != .never {
                        Text("Automatically delete local copies of synced recordings older than \(viewModel.autoCleanupThreshold.displayName). iCloud copies are preserved.")
                    } else {
                        Text("Automatic cleanup is disabled")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showDoneButton {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
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
            .confirmationDialog(
                "Clean Up Storage",
                isPresented: $viewModel.showingCleanupConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Local Copies", role: .destructive) {
                    Task {
                        await viewModel.performManualCleanup()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete local copies of synced recordings older than \(viewModel.autoCleanupThreshold.displayName). iCloud copies will be preserved.")
            }
            .sheet(isPresented: $viewModel.showingStorageBreakdown) {
                StorageBreakdownView(storageUsage: viewModel.storageUsage ?? StorageUsage(totalBytes: 0, recordingCount: 0, perRecordingSizes: [:]))
            }
        }
    }
}

#Preview {
    SettingsView(
        storageManager: StorageManager(),
        cloudSyncService: CloudSyncService(storageManager: StorageManager())
    )
}
