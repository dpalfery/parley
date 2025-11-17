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
        sampleRecording.audioFileName = "sample.m4a"
        sampleRecording.fileSize = 5242880
        sampleRecording.isSynced = false
        sampleRecording.lastModified = Date()
        sampleRecording.searchableContent = "sample meeting"
        
        do {
            try viewContext.save()
        } catch {
            fatalError("Failed to create preview data: \(error)")
        }
        
        return controller
    }()
    
    /// The persistent container with CloudKit support
    let container: NSPersistentCloudKitContainer
    
    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Initializes the persistence controller
    /// - Parameter inMemory: If true, uses in-memory store for testing/previews
    init(inMemory: Bool = false) {
        // Use programmatic model
        let model = CoreDataModel.createModel()
        container = NSPersistentCloudKitContainer(name: "MeetingRecorder", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit sync
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }
            
            // Enable persistent history tracking for CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Configure CloudKit container options
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.meetingrecorder.app"
            )
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // In production, handle this error appropriately
                fatalError("Unresolved error \(error), \(error.userInfo)")
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