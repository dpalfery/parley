//
//  ParleyApp.swift
//  Parley
//
//  Created on 2025-11-16.
//

import SwiftUI

@main
struct ParleyApp: App {
    // MARK: - Properties

    @StateObject private var appEnvironment = AppEnvironment.shared
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainTabView()
                    .environmentObject(appEnvironment)
                    .environment(\.managedObjectContext, appEnvironment.persistenceController.viewContext)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(to: newPhase)
        }
    }

    // MARK: - Lifecycle Handling

    /// Handles app lifecycle phase changes
    private func handleScenePhaseChange(to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active
            break
        case .inactive:
            // App became inactive (e.g., during transition)
            break
        case .background:
            // App moved to background - save context if needed
            saveContext()
        @unknown default:
            break
        }
    }

    /// Saves the Core Data context
    private func saveContext() {
        do {
            try appEnvironment.persistenceController.saveContext()
        } catch {
            // Log error but don't crash
            print("Failed to save context: \(error)")
        }
    }
}