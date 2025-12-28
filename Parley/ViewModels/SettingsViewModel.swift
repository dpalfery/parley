//
//  SettingsViewModel.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import Combine

/// View model for the settings screen
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var selectedAudioQuality: AudioQuality
    @Published var iCloudSyncEnabled: Bool
    @Published var storageUsage: StorageUsage?
    @Published var autoCleanupThreshold: CleanupThreshold
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingCleanupConfirmation: Bool = false
    @Published var showingStorageBreakdown: Bool = false
    
    // MARK: - Private Properties
    
    private let storageManager: StorageManagerProtocol
    private let cloudSyncService: CloudSyncServiceProtocol
    private let userDefaults = UserDefaults.standard
    
    private let audioQualityKey = "com.parley.audioQuality"
    private let cleanupThresholdKey = "com.parley.autoCleanupThreshold"
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(storageManager: StorageManagerProtocol, cloudSyncService: CloudSyncServiceProtocol) {
        self.storageManager = storageManager
        self.cloudSyncService = cloudSyncService
        
        // Load saved preferences
        self.selectedAudioQuality = AudioQuality(rawValue: userDefaults.integer(forKey: audioQualityKey)) ?? .medium
        self.iCloudSyncEnabled = userDefaults.bool(forKey: "com.parley.iCloudSyncEnabled")
        self.autoCleanupThreshold = CleanupThreshold(rawValue: userDefaults.integer(forKey: cleanupThresholdKey)) ?? .never
        
        // Load storage usage
        Task {
            await loadStorageUsage()
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads the current storage usage
    func loadStorageUsage() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let usage = try await storageManager.getStorageUsage()
            storageUsage = usage
        } catch {
            errorMessage = "Failed to load storage usage: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Updates the audio quality setting
    func updateAudioQuality(_ quality: AudioQuality) {
        selectedAudioQuality = quality
        userDefaults.set(quality.rawValue, forKey: audioQualityKey)
    }
    
    /// Toggles iCloud sync on or off
    func toggleiCloudSync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if iCloudSyncEnabled {
                try await cloudSyncService.disableSync()
                iCloudSyncEnabled = false
            } else {
                try await cloudSyncService.enableSync()
                iCloudSyncEnabled = true
            }
        } catch {
            errorMessage = "Failed to update sync settings: \(error.localizedDescription)"
            // Revert the toggle
            iCloudSyncEnabled = !iCloudSyncEnabled
        }
        
        isLoading = false
    }
    
    /// Updates the auto-cleanup threshold
    func updateCleanupThreshold(_ threshold: CleanupThreshold) {
        autoCleanupThreshold = threshold
        userDefaults.set(threshold.rawValue, forKey: cleanupThresholdKey)
    }
    
    /// Performs manual cleanup of local files
    func performManualCleanup() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Only cleanup if threshold is not "never"
            if autoCleanupThreshold != .never {
                try await storageManager.performAutoCleanup(olderThanDays: autoCleanupThreshold.days)
            }
            
            // Reload storage usage
            await loadStorageUsage()
        } catch {
            errorMessage = "Failed to perform cleanup: \(error.localizedDescription)"
        }
        
        isLoading = false
        showingCleanupConfirmation = false
    }
    
    /// Shows the cleanup confirmation dialog
    func showCleanupConfirmation() {
        showingCleanupConfirmation = true
    }
    
    /// Shows the storage breakdown view
    func showStorageBreakdown() {
        showingStorageBreakdown = true
    }
}

// MARK: - Supporting Types

/// Auto-cleanup threshold options
enum CleanupThreshold: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case fourteenDays = 14
    case thirtyDays = 30
    case sixtyDays = 60
    case ninetyDays = 90
    case never = 0

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .sevenDays: return "7 days"
        case .fourteenDays: return "14 days"
        case .thirtyDays: return "30 days"
        case .sixtyDays: return "60 days"
        case .ninetyDays: return "90 days"
        case .never: return "Never"
        }
    }

    var days: Int {
        rawValue
    }
}
