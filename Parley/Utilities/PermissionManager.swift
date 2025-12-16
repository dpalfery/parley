//
//  PermissionManager.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import AVFoundation
import Speech
import SwiftUI
import os.log

/// Manages app permissions for microphone and speech recognition
@MainActor
class PermissionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var microphonePermissionStatus: PermissionStatus = .notDetermined
    @Published var speechRecognitionPermissionStatus: PermissionStatus = .notDetermined
    @Published var showPermissionAlert = false
    @Published var permissionAlertMessage = ""
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.meetingrecorder.app", category: "PermissionManager")
    
    // MARK: - Permission Status Enum
    
    enum PermissionStatus {
        case notDetermined
        case granted
        case denied
        case restricted
    }
    
    // MARK: - Initialization
    
    init() {
        checkCurrentPermissions()
    }
    
    // MARK: - Permission Checking
    
    /// Checks current permission status for all required permissions
    func checkCurrentPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
    }
    
    /// Checks microphone permission status
    private func checkMicrophonePermission() {
        let status = AVAudioSession.sharedInstance().recordPermission
        
        switch status {
        case .granted:
            microphonePermissionStatus = .granted
        case .denied:
            microphonePermissionStatus = .denied
        case .undetermined:
            microphonePermissionStatus = .notDetermined
        @unknown default:
            microphonePermissionStatus = .notDetermined
        }
        
        logger.info("Microphone permission status: \(String(describing: self.microphonePermissionStatus))")
    }
    
    /// Checks speech recognition permission status
    private func checkSpeechRecognitionPermission() {
        let status = SFSpeechRecognizer.authorizationStatus()
        
        switch status {
        case .authorized:
            speechRecognitionPermissionStatus = .granted
        case .denied:
            speechRecognitionPermissionStatus = .denied
        case .restricted:
            speechRecognitionPermissionStatus = .restricted
        case .notDetermined:
            speechRecognitionPermissionStatus = .notDetermined
        @unknown default:
            speechRecognitionPermissionStatus = .notDetermined
        }
        
        logger.info("Speech recognition permission status: \(String(describing: self.speechRecognitionPermissionStatus))")
    }
    
    // MARK: - Permission Requests
    
    /// Requests microphone permission
    /// - Returns: True if permission granted, false otherwise
    func requestMicrophonePermission() async -> Bool {
        // Check if already granted
        if microphonePermissionStatus == .granted {
            return true
        }
        
        // Check if denied - show settings alert
        if microphonePermissionStatus == .denied {
            showSettingsAlert(for: "Microphone")
            return false
        }
        
        // Request permission
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        // Update status
        await MainActor.run {
            microphonePermissionStatus = granted ? .granted : .denied
            
            if !granted {
                showSettingsAlert(for: "Microphone")
            }
        }
        
        logger.info("Microphone permission request result: \(granted)")
        return granted
    }
    
    /// Requests speech recognition permission
    /// - Returns: True if permission granted, false otherwise
    func requestSpeechRecognitionPermission() async -> Bool {
        // Check if already granted
        if speechRecognitionPermissionStatus == .granted {
            return true
        }
        
        // Check if denied or restricted - show settings alert
        if speechRecognitionPermissionStatus == .denied || speechRecognitionPermissionStatus == .restricted {
            showSettingsAlert(for: "Speech Recognition")
            return false
        }
        
        // Request permission
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        // Update status
        await MainActor.run {
            switch status {
            case .authorized:
                speechRecognitionPermissionStatus = .granted
            case .denied:
                speechRecognitionPermissionStatus = .denied
                showSettingsAlert(for: "Speech Recognition")
            case .restricted:
                speechRecognitionPermissionStatus = .restricted
                showSettingsAlert(for: "Speech Recognition")
            case .notDetermined:
                speechRecognitionPermissionStatus = .notDetermined
            @unknown default:
                speechRecognitionPermissionStatus = .notDetermined
            }
        }
        
        logger.info("Speech recognition permission request result: \(status.rawValue)")
        return status == .authorized
    }
    
    /// Requests all required permissions for recording
    /// - Returns: True if all permissions granted, false otherwise
    func requestRecordingPermissions() async -> Bool {
        let micGranted = await requestMicrophonePermission()
        guard micGranted else { return false }
        
        let speechGranted = await requestSpeechRecognitionPermission()
        return speechGranted
    }
    
    // MARK: - Settings Alert
    
    /// Shows an alert directing user to settings
    private func showSettingsAlert(for permission: String) {
        permissionAlertMessage = "\(permission) access is required to use this feature. Please enable it in Settings."
        showPermissionAlert = true
    }
    
    /// Opens app settings
    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}
