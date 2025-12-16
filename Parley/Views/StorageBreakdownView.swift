//
//  StorageBreakdownView.swift
//  Parley
//
//  Created on 2025-11-16.
//

import SwiftUI

/// View displaying detailed storage breakdown by recording
struct StorageBreakdownView: View {
    let storageUsage: StorageUsage
    @Environment(\.dismiss) private var dismiss
    @State private var sortedRecordings: [(UUID, Int64)] = []
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Total Storage")
                            .font(.headline)
                        Spacer()
                        Text(storageUsage.formattedTotalSize)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Number of Recordings")
                        Spacer()
                        Text("\(storageUsage.recordingCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    if storageUsage.recordingCount > 0 {
                        HStack {
                            Text("Average Size")
                            Spacer()
                            Text(formatBytes(storageUsage.totalBytes / Int64(storageUsage.recordingCount)))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Summary")
                }
                
                if !sortedRecordings.isEmpty {
                    Section {
                        ForEach(sortedRecordings, id: \.0) { recordingID, size in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recordingID.uuidString.prefix(8))
                                        .font(.system(.body, design: .monospaced))
                                    
                                    // Show percentage of total storage
                                    if storageUsage.totalBytes > 0 {
                                        let percentage = Double(size) / Double(storageUsage.totalBytes) * 100
                                        Text("\(String(format: "%.1f", percentage))% of total")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(formatBytes(size))
                                        .font(.body)
                                    
                                    // Visual indicator
                                    if storageUsage.totalBytes > 0 {
                                        let percentage = Double(size) / Double(storageUsage.totalBytes)
                                        ProgressView(value: percentage)
                                            .frame(width: 60)
                                            .tint(colorForPercentage(percentage))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Recordings by Size")
                    } footer: {
                        Text("Recordings are sorted by size, largest first")
                    }
                } else {
                    Section {
                        Text("No recordings found")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Storage Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSortedRecordings()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Loads and sorts recordings by size
    private func loadSortedRecordings() {
        sortedRecordings = storageUsage.perRecordingSizes
            .sorted { $0.value > $1.value }
    }
    
    /// Formats bytes into human-readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let bytesDouble = Double(bytes)
        
        if bytesDouble < 1024 {
            return "\(bytes) B"
        } else if bytesDouble < 1024 * 1024 {
            return String(format: "%.1f KB", bytesDouble / 1024)
        } else if bytesDouble < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytesDouble / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", bytesDouble / (1024 * 1024 * 1024))
        }
    }
    
    /// Returns a color based on the percentage of total storage
    private func colorForPercentage(_ percentage: Double) -> Color {
        if percentage > 0.2 {
            return .red
        } else if percentage > 0.1 {
            return .orange
        } else if percentage > 0.05 {
            return .yellow
        } else {
            return .blue
        }
    }
}

#Preview {
    StorageBreakdownView(
        storageUsage: StorageUsage(
            totalBytes: 150_000_000,
            recordingCount: 5,
            perRecordingSizes: [
                UUID(): 50_000_000,
                UUID(): 40_000_000,
                UUID(): 30_000_000,
                UUID(): 20_000_000,
                UUID(): 10_000_000
            ]
        )
    )
}
