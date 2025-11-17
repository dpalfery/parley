//
//  CoreDataModel.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import CoreData
import Foundation

/// Programmatically creates the Core Data model
class CoreDataModel {
    static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create RecordingEntity
        let recordingEntity = NSEntityDescription()
        recordingEntity.name = "RecordingEntity"
        recordingEntity.managedObjectClassName = "RecordingEntity"
        
        // RecordingEntity attributes
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false
        
        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false
        
        let dateAttr = NSAttributeDescription()
        dateAttr.name = "date"
        dateAttr.attributeType = .dateAttributeType
        dateAttr.isOptional = false
        
        let durationAttr = NSAttributeDescription()
        durationAttr.name = "duration"
        durationAttr.attributeType = .doubleAttributeType
        durationAttr.defaultValue = 0.0
        
        let audioFileNameAttr = NSAttributeDescription()
        audioFileNameAttr.name = "audioFileName"
        audioFileNameAttr.attributeType = .stringAttributeType
        audioFileNameAttr.isOptional = false
        
        let transcriptDataAttr = NSAttributeDescription()
        transcriptDataAttr.name = "transcriptData"
        transcriptDataAttr.attributeType = .binaryDataAttributeType
        transcriptDataAttr.isOptional = true
        
        let speakersDataAttr = NSAttributeDescription()
        speakersDataAttr.name = "speakersData"
        speakersDataAttr.attributeType = .binaryDataAttributeType
        speakersDataAttr.isOptional = true
        
        let tagsDataAttr = NSAttributeDescription()
        tagsDataAttr.name = "tagsData"
        tagsDataAttr.attributeType = .binaryDataAttributeType
        tagsDataAttr.isOptional = true
        
        let notesDataAttr = NSAttributeDescription()
        notesDataAttr.name = "notesData"
        notesDataAttr.attributeType = .binaryDataAttributeType
        notesDataAttr.isOptional = true
        
        let fileSizeAttr = NSAttributeDescription()
        fileSizeAttr.name = "fileSize"
        fileSizeAttr.attributeType = .integer64AttributeType
        fileSizeAttr.defaultValue = 0
        
        let isSyncedAttr = NSAttributeDescription()
        isSyncedAttr.name = "isSynced"
        isSyncedAttr.attributeType = .booleanAttributeType
        isSyncedAttr.defaultValue = false
        
        let lastModifiedAttr = NSAttributeDescription()
        lastModifiedAttr.name = "lastModified"
        lastModifiedAttr.attributeType = .dateAttributeType
        lastModifiedAttr.isOptional = false
        
        let searchableContentAttr = NSAttributeDescription()
        searchableContentAttr.name = "searchableContent"
        searchableContentAttr.attributeType = .stringAttributeType
        searchableContentAttr.isOptional = true
        
        recordingEntity.properties = [
            idAttr, titleAttr, dateAttr, durationAttr, audioFileNameAttr,
            transcriptDataAttr, speakersDataAttr, tagsDataAttr, notesDataAttr,
            fileSizeAttr, isSyncedAttr, lastModifiedAttr, searchableContentAttr
        ]
        
        // Create SpeakerProfileEntity
        let speakerEntity = NSEntityDescription()
        speakerEntity.name = "SpeakerProfileEntity"
        speakerEntity.managedObjectClassName = "SpeakerProfileEntity"
        
        // SpeakerProfileEntity attributes
        let speakerIdAttr = NSAttributeDescription()
        speakerIdAttr.name = "id"
        speakerIdAttr.attributeType = .stringAttributeType
        speakerIdAttr.isOptional = false
        
        let displayNameAttr = NSAttributeDescription()
        displayNameAttr.name = "displayName"
        displayNameAttr.attributeType = .stringAttributeType
        displayNameAttr.isOptional = false
        
        let voiceCharacteristicsAttr = NSAttributeDescription()
        voiceCharacteristicsAttr.name = "voiceCharacteristics"
        voiceCharacteristicsAttr.attributeType = .binaryDataAttributeType
        voiceCharacteristicsAttr.isOptional = true
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        let lastUsedAttr = NSAttributeDescription()
        lastUsedAttr.name = "lastUsed"
        lastUsedAttr.attributeType = .dateAttributeType
        lastUsedAttr.isOptional = false
        
        speakerEntity.properties = [
            speakerIdAttr, displayNameAttr, voiceCharacteristicsAttr,
            createdAtAttr, lastUsedAttr
        ]
        
        model.entities = [recordingEntity, speakerEntity]
        
        return model
    }
}
