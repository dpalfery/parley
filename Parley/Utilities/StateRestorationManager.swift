//
//  StateRestorationManager.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import os.log

/// Manages app state restoration for interrupted recordings
class StateRestorationManager {
    
    // MARK: - Properties
    
    private let userDefaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.parley.app", category: "StateRestoration")
    
    // MARK: - Keys
    
    private enum Keys {
        static let hasInterruptedRecording = "hasInterruptedRecording"
        static let interruptedRecordingID = "interruptedRecordingID"
        static let interruptedRecordingStartTime = "interruptedRecordingStartTime"
        static let interruptedRecordingDuration = "interruptedRecordingDuration"
        static let interruptedRecordingState = "interruptedRecordingState"
    }
    
    // MARK: - State Restoration Data
    
    struct InterruptedRecordingState: Codable {
        let recordingID: UUID
        let startTime: Date
        let duration: TimeInterval
        let state: String // "recording" or "paused"
        let audioFileName: String
        let transcript: [TranscriptSegment]
    }
    
    // MARK: - Save State
    
    /// Saves the current recording state for restoration
    func saveRecordingState(
        recordingID: UUID,
        startTime: Date,
        duration: TimeInterval,
        state: RecordingState,
        audioFileName: String,
        transcript: [TranscriptSegment]
    ) {
        let stateData = InterruptedRecordingState(
            recordingID: recordingID,
            startTime: startTime,
            duration: duration,
            state: stateString(from: state),
            audioFileName: audioFileName,
            transcript: transcript
        )
        
        if let encoded = try? JSONEncoder().encode(stateData) {
            userDefaults.set(true, forKey: Keys.hasInterruptedRecording)
            userDefaults.set(encoded, forKey: Keys.interruptedRecordingID)
            logger.info("Saved recording state for restoration: \(recordingID) with \(transcript.count) segments")
        }
    }
    
    /// Clears the saved recording state
    func clearRecordingState() {
        userDefaults.removeObject(forKey: Keys.hasInterruptedRecording)
        userDefaults.removeObject(forKey: Keys.interruptedRecordingID)
        logger.info("Cleared recording state")
    }
    
    // MARK: - Restore State
    
    /// Checks if there is an interrupted recording to restore
    func hasInterruptedRecording() -> Bool {
        return userDefaults.bool(forKey: Keys.hasInterruptedRecording)
    }
    
    /// Retrieves the interrupted recording state
    func getInterruptedRecordingState() -> InterruptedRecordingState? {
        guard let data = userDefaults.data(forKey: Keys.interruptedRecordingID),
              let state = try? JSONDecoder().decode(InterruptedRecordingState.self, from: data) else {
            return nil
        }
        
        logger.info("Retrieved interrupted recording state: \(state.recordingID)")
        return state
    }
    
    // MARK: - Helper Methods
    
    private func stateString(from state: RecordingState) -> String {
        switch state {
        case .recording:
            return "recording"
        case .paused:
            return "paused"
        default:
            return "idle"
        }
    }
}
