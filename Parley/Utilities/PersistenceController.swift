//
//  PersistenceController.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import CoreData
import Foundation

/// Manages Core Data persistence with iCloud sync support
class PersistenceController {
    /// Shared singleton instance for app-wide use
    static let shared = PersistenceController()
    
    /// Preview instance for SwiftUI previews with in-memory store
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Create sample data for previews
        let sampleRecording = RecordingEntity(context: viewContext)
        sampleRecording.id = UUID()
        sampleRecording.title = "Sample Meeting"
        sampleRecording.date = Date()
        sampleRecording.duration = 1800.0
        sampleRecording.audioFileName = "sample.\(RecordingAudioConfig.audioFileExtension)"
        sampleRecording.fileSize = 5242880
        sampleRecording.isSynced = false
        sampleRecording.lastModified = Date()
        sampleRecording.searchableContent = "sample meeting"
        
        do {
            try viewContext.save()
        } catch {
            print("Warning: Failed to create preview data: \(error)")
            // Don't crash in preview mode - just log the error
        }
        
        return controller
    }()
    
    /// The persistent container (CloudKit disabled for now)
    let container: NSPersistentContainer

    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Initializes the persistence controller
    /// - Parameter inMemory: If true, uses in-memory store for testing/previews
    init(inMemory: Bool = false) {
        // Use xcdatamodeld model
        // Note: Using NSPersistentContainer instead of NSPersistentCloudKitContainer
        // CloudKit sync temporarily disabled until iCloud container is configured
        container = NSPersistentContainer(name: "MeetingRecorder")

        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Check if this is a model incompatibility error
                if error.code == NSPersistentStoreIncompatibleVersionHashError || 
                   error.code == NSMigrationMissingSourceModelError ||
                   error.code == 134060 { // CloudKit model incompatibility
                    
                    print("Core Data model incompatibility detected. Attempting to reset store...")
                    
                    // Delete the existing store and try again
                    if let storeURL = storeDescription.url {
                        do {
                            try FileManager.default.removeItem(at: storeURL)
                            print("Deleted incompatible Core Data store")
                            
                            // Try loading again with fresh store
                            self.container.loadPersistentStores { _, retryError in
                                if let retryError = retryError {
                                    fatalError("Failed to create new Core Data store: \(retryError)")
                                }
                            }
                            return
                        } catch {
                            print("Failed to delete existing store: \(error)")
                        }
                    }
                }
                
                // If we get here, it's an unhandled error
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Save Context
    
    /// Saves changes in the view context if there are any
    /// - Throws: StorageError if save fails
    func saveContext() throws {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                throw StorageError.saveContextFailed(underlying: error)
            }
        }
    }
    
    // MARK: - Background Context
    
    /// Creates a new background context for performing operations off the main thread
    /// - Returns: A new NSManagedObjectContext configured for background use
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Performs a block on a background context
    /// - Parameter block: The block to execute with the background context
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
}