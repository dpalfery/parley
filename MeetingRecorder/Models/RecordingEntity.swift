//
//  RecordingEntity.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import CoreData
import Foundation

/// Core Data entity for storing recording metadata
@objc(RecordingEntity)
public class RecordingEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var date: Date?
    @NSManaged public var duration: Double
    @NSManaged public var audioFileName: String?
    @NSManaged public var transcriptData: Data?
    @NSManaged public var speakersData: Data?
    @NSManaged public var tagsData: Data?
    @NSManaged public var notesData: Data?
    @NSManaged public var fileSize: Int64
    @NSManaged public var isSynced: Bool
    @NSManaged public var lastModified: Date?
    @NSManaged public var searchableContent: String?
}

extension RecordingEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecordingEntity> {
        return NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
    }
}
