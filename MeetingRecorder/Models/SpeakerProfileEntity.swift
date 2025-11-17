//
//  SpeakerProfileEntity.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import CoreData
import Foundation

/// Core Data entity for storing speaker profiles
@objc(SpeakerProfileEntity)
public class SpeakerProfileEntity: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var displayName: String?
    @NSManaged public var voiceCharacteristics: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastUsed: Date?
}

extension SpeakerProfileEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SpeakerProfileEntity> {
        return NSFetchRequest<SpeakerProfileEntity>(entityName: "SpeakerProfileEntity")
    }
}
