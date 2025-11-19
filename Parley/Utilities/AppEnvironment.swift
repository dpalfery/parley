//
//  AppEnvironment.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation
import SwiftUI

/// Manages app-wide services and dependencies
@MainActor
class AppEnvironment: ObservableObject {
    /// Shared singleton instance
    static let shared = AppEnvironment()
    
    // MARK: - Core Services
    
    let persistenceController: PersistenceController
    let recordingService: RecordingService
    let transcriptionService: TranscriptionService
    let speakerService: SpeakerService
    let storageManager: StorageManager
    let cloudSyncService: CloudSyncService
    let exportService: ExportService
    
    // MARK: - Managers
    
    let permissionManager: PermissionManager
    let stateRestorationManager: StateRestorationManager
    
    // MARK: - Initialization
    
    private init() {
        // Initialize persistence
        self.persistenceController = PersistenceController.shared
        
        // Initialize managers
        self.permissionManager = PermissionManager()
        self.stateRestorationManager = StateRestorationManager()
        
        // Initialize services
        self.recordingService = RecordingService()
        self.transcriptionService = TranscriptionService()
        self.speakerService = SpeakerService()
        self.storageManager = StorageManager(persistenceController: persistenceController)
        self.cloudSyncService = CloudSyncService(storageManager: self.storageManager)
        self.exportService = ExportService()
    }
    
    /// Creates a preview environment for SwiftUI previews
    static func preview() -> AppEnvironment {
        let environment = AppEnvironment()
        return environment
    }
}
