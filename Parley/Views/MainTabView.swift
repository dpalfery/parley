//
//  MainTabView.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

/// Main tab-based navigation structure for the app
struct MainTabView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var showPermissionRequest = false
    @State private var showRestorationAlert = false
    @State private var interruptedRecordingState: StateRestorationManager.InterruptedRecordingState?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Recordings List Tab
            RecordingListView(storageManager: appEnvironment.storageManager)
                .tabItem {
                    Label("Recordings", systemImage: "list.bullet")
                }
                .tag(0)
            
            // New Recording Tab
            RecordingView(
                recordingService: appEnvironment.recordingService,
                transcriptionService: appEnvironment.transcriptionService,
                speakerService: appEnvironment.speakerService,
                storageManager: appEnvironment.storageManager,
                permissionManager: appEnvironment.permissionManager
            )
            .tabItem {
                Label("Record", systemImage: "record.circle")
            }
            .tag(1)
            
            // Settings Tab
            SettingsView(
                storageManager: appEnvironment.storageManager,
                cloudSyncService: appEnvironment.cloudSyncService
            )
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
        .sheet(isPresented: $showPermissionRequest) {
            PermissionRequestView(isPresented: $showPermissionRequest)
                .environmentObject(appEnvironment)
                .interactiveDismissDisabled()
        }
        .alert("Restore Recording?", isPresented: $showRestorationAlert) {
            Button("Restore") {
                restoreInterruptedRecording()
            }
            Button("Discard", role: .destructive) {
                discardInterruptedRecording()
            }
        } message: {
            if let state = interruptedRecordingState {
                Text("A recording was interrupted. Would you like to restore it?\n\nDuration: \(formatDuration(state.duration))")
            }
        }
        .onAppear {
            handleOnAppear()
        }
    }
    
    // MARK: - Lifecycle Handling
    
    private func handleOnAppear() {
        // Check for first launch and permissions
        if !hasCompletedOnboarding {
            checkPermissionsOnFirstLaunch()
        }
        
        // Check for interrupted recording
        checkForInterruptedRecording()
    }
    
    private func checkPermissionsOnFirstLaunch() {
        // Check if permissions are already granted
        let micGranted = appEnvironment.permissionManager.microphonePermissionStatus == .granted
        let speechGranted = appEnvironment.permissionManager.speechRecognitionPermissionStatus == .granted
        
        if !micGranted || !speechGranted {
            // Show permission request on first launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showPermissionRequest = true
            }
        } else {
            hasCompletedOnboarding = true
        }
    }
    
    private func checkForInterruptedRecording() {
        if appEnvironment.stateRestorationManager.hasInterruptedRecording() {
            interruptedRecordingState = appEnvironment.stateRestorationManager.getInterruptedRecordingState()
            showRestorationAlert = true
        }
    }
    
    // MARK: - State Restoration
    
    private func restoreInterruptedRecording() {
        guard let state = interruptedRecordingState else { return }
        
        // Switch to recording tab
        selectedTab = 1
        
        // Note: The actual restoration logic would be handled by RecordingViewModel
        // This is just the UI flow to navigate to the recording tab
        
        // Clear the restoration state
        appEnvironment.stateRestorationManager.clearRecordingState()
    }
    
    private func discardInterruptedRecording() {
        // Clear the restoration state
        appEnvironment.stateRestorationManager.clearRecordingState()
        interruptedRecordingState = nil
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        MainTabView()
            .environmentObject(AppEnvironment.preview())
    }
}
