//
//  RecordingService.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import AVFoundation
import UIKit
import os.log

/// Implementation of RecordingServiceProtocol for audio recording management
final class RecordingService: NSObject, RecordingServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private var _recordingState: RecordingState = .idle
    @Published private var _audioLevel: Float = 0.0
    @Published private var _duration: TimeInterval = 0.0
    
    var recordingState: Published<RecordingState>.Publisher { $_recordingState }
    var audioLevel: Published<Float>.Publisher { $_audioLevel }
    var duration: Published<TimeInterval>.Publisher { $_duration }
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var currentSession: RecordingSession?
    private var meteringTimer: Timer?
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0.0
    private var pauseStartTime: Date?
    private var pauseResumeMarkers: [(timestamp: TimeInterval, isPause: Bool)] = []
    
    private let logger = Logger(subsystem: "com.meetingrecorder.app", category: "RecordingService")
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        meteringTimer?.invalidate()
    }
    
    // MARK: - Audio Session Configuration
    
    /// Configures the audio session for recording
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure session with record category and allow bluetooth
            try audioSession.setCategory(.record, mode: .default, options: [.allowBluetoothHFP])
            try audioSession.setActive(true, options: [])
            
            logger.info("Audio session configured successfully")
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
            throw RecordingError.audioSessionConfigurationFailed
        }
    }
    
    /// Deactivates the audio session
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            logger.info("Audio session deactivated")
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    /// Requests microphone permission
    private func requestMicrophonePermission() async throws {
        let status = AVAudioSession.sharedInstance().recordPermission
        
        switch status {
        case .granted:
            return
        case .denied:
            throw RecordingError.microphonePermissionDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                throw RecordingError.microphonePermissionDenied
            }
        @unknown default:
            throw RecordingError.microphonePermissionDenied
        }
    }
    
    // MARK: - Notification Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        // Monitor app state transitions for background recording
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began (phone call, alarm, etc.)
            logger.info("Audio session interrupted")
            if _recordingState == .recording {
                Task {
                    try? await pauseRecording()
                }
            }
            
        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                logger.info("Audio session interruption ended, should resume")
                // Reactivate audio session
                do {
                    try configureAudioSession()
                } catch {
                    logger.error("Failed to reactivate audio session after interruption: \(error.localizedDescription)")
                    ErrorLogger.log(RecordingError.audioSessionConfigurationFailed, context: "handleInterruption")
                }
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Audio device was removed (e.g., headphones unplugged)
            logger.info("Audio route changed: device unavailable")
            // Continue recording with built-in microphone
            
        default:
            break
        }
    }
    
    @objc private func handleAppDidEnterBackground(notification: Notification) {
        // Ensure audio session remains active for background recording
        if _recordingState == .recording || _recordingState == .paused {
            logger.info("App entered background while recording - maintaining audio session")
            
            // Audio session should remain active due to background audio mode
            // The recording will continue automatically
            
            // Verify audio session is still active
            let audioSession = AVAudioSession.sharedInstance()
            if !audioSession.isOtherAudioPlaying {
                do {
                    try audioSession.setActive(true, options: [])
                    logger.info("Audio session reactivated for background recording")
                } catch {
                    logger.error("Failed to maintain audio session in background: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func handleAppWillEnterForeground(notification: Notification) {
        // App returning to foreground
        if _recordingState == .recording || _recordingState == .paused {
            logger.info("App entering foreground while recording - verifying recording state")
            
            // Verify recording is still active
            if let recorder = audioRecorder {
                if _recordingState == .recording && !recorder.isRecording {
                    logger.warning("Recording was interrupted in background")
                    // Recording was stopped unexpectedly - update state
                    _recordingState = .paused
                }
            }
        }
    }
    
    // MARK: - RecordingServiceProtocol Implementation
    
    func startRecording(quality: AudioQuality) async throws -> RecordingSession {
        logger.info("🎤 startRecording() entered")

        // Check if already recording
        guard _recordingState == .idle else {
            logger.error("🎤 Already recording - throwing error")
            throw RecordingError.recordingInProgress
        }
        logger.info("🎤 State check passed - is idle")

        // Request microphone permission
        logger.info("🎤 About to request microphone permission")
        try await requestMicrophonePermission()
        logger.info("🎤 Microphone permission granted")

        // Configure audio session
        logger.info("🎤 Configuring audio session")
        try configureAudioSession()
        logger.info("🎤 Audio session configured")

        // Check available disk space
        logger.info("🎤 Checking disk space")
        try checkDiskSpace()
        logger.info("🎤 Disk space check passed")
        
        // Create session ID and audio URL first
        let sessionId = UUID()
        let audioURL = try createAudioFileURL(for: sessionId)
        
        // Create recording session
        let session = RecordingSession(
            id: sessionId,
            startTime: Date(),
            quality: quality,
            audioFileURL: audioURL
        )
        currentSession = session
        
        // Setup audio recorder
        let settings = createAudioSettings(for: quality)
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Start recording
            guard audioRecorder?.record() == true else {
                throw RecordingError.audioEngineFailure
            }
            
            // Update state
            _recordingState = .recording
            recordingStartTime = Date()
            pausedDuration = 0.0
            pauseResumeMarkers = []
            
            // Start metering timer
            startMeteringTimer()
            
            logger.info("Recording started with quality: \(quality)")
            
            return session
            
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            deactivateAudioSession()
            throw RecordingError.audioEngineFailure
        }
    }
    
    func pauseRecording() async throws {
        guard _recordingState == .recording else {
            throw RecordingError.noActiveRecording
        }
        
        guard let recorder = audioRecorder, recorder.isRecording else {
            throw RecordingError.noActiveRecording
        }
        
        // Pause the recorder
        recorder.pause()
        
        // Record pause timestamp
        let currentDuration = calculateCurrentDuration()
        pauseStartTime = Date()
        pauseResumeMarkers.append((timestamp: currentDuration, isPause: true))
        
        // Update state
        _recordingState = .paused
        
        logger.info("Recording paused at \(currentDuration) seconds")
    }
    
    func resumeRecording() async throws {
        guard _recordingState == .paused else {
            throw RecordingError.noActiveRecording
        }
        
        guard let recorder = audioRecorder else {
            throw RecordingError.noActiveRecording
        }
        
        // Calculate paused duration
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        
        // Record resume timestamp
        let currentDuration = calculateCurrentDuration()
        pauseResumeMarkers.append((timestamp: currentDuration, isPause: false))
        
        // Resume recording
        recorder.record()
        
        // Update state
        _recordingState = .recording
        
        logger.info("Recording resumed at \(currentDuration) seconds")
    }
    
    func stopRecording() async throws -> Recording {
        guard _recordingState == .recording || _recordingState == .paused else {
            throw RecordingError.noActiveRecording
        }
        
        guard let recorder = audioRecorder,
              let session = currentSession else {
            throw RecordingError.noActiveRecording
        }
        
        // Update state
        _recordingState = .processing
        
        // Stop metering timer
        stopMeteringTimer()
        
        // Stop recording
        recorder.stop()
        
        // Calculate final duration
        let finalDuration = calculateCurrentDuration()
        
        // Get audio file URL and size
        let audioURL = recorder.url
        let fileSize = try getFileSize(at: audioURL)
        
        // Create recording object
        let recording = Recording(
            id: session.id,
            title: generateDefaultTitle(for: session.startTime),
            date: session.startTime,
            duration: finalDuration,
            audioFileURL: audioURL,
            transcript: [],
            speakers: [],
            tags: [],
            notes: [],
            fileSize: fileSize,
            isSynced: false,
            lastModified: Date()
        )
        
        // Clean up
        audioRecorder = nil
        currentSession = nil
        recordingStartTime = nil
        pausedDuration = 0.0
        pauseStartTime = nil
        pauseResumeMarkers = []
        
        // Deactivate audio session
        deactivateAudioSession()
        
        // Update state
        _recordingState = .idle
        _audioLevel = 0.0
        _duration = 0.0
        
        logger.info("Recording stopped. Duration: \(finalDuration) seconds, Size: \(fileSize) bytes")
        
        return recording
    }
    
    func cancelRecording() async throws {
        guard _recordingState == .recording || _recordingState == .paused else {
            throw RecordingError.noActiveRecording
        }
        
        guard let recorder = audioRecorder else {
            throw RecordingError.noActiveRecording
        }
        
        // Stop metering timer
        stopMeteringTimer()
        
        // Stop and delete recording
        recorder.stop()
        recorder.deleteRecording()
        
        // Clean up
        audioRecorder = nil
        currentSession = nil
        recordingStartTime = nil
        pausedDuration = 0.0
        pauseStartTime = nil
        pauseResumeMarkers = []
        
        // Deactivate audio session
        deactivateAudioSession()
        
        // Update state
        _recordingState = .idle
        _audioLevel = 0.0
        _duration = 0.0
        
        logger.info("Recording cancelled")
    }
    
    // MARK: - Helper Methods
    
    private func createAudioFileURL(for id: UUID) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        let sessionPath = recordingsPath.appendingPathComponent(id.uuidString, isDirectory: true)
        
        // Create directories if needed
        try FileManager.default.createDirectory(at: sessionPath, withIntermediateDirectories: true)
        
        return sessionPath.appendingPathComponent(RecordingAudioConfig.audioFileName)
    }
    
    private func createAudioSettings(for quality: AudioQuality) -> [String: Any] {
        RecordingAudioConfig.audioSettings(for: quality)
    }
    
    private func checkDiskSpace() throws {
        guard let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw RecordingError.diskSpaceInsufficient
        }
        
        do {
            let values = try path.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                // Require at least 100 MB free space
                let requiredSpace: Int64 = 100 * 1024 * 1024
                if capacity < requiredSpace {
                    throw RecordingError.diskSpaceInsufficient
                }
            }
        } catch {
            // If we can't determine space, allow recording to proceed
            logger.warning("Could not determine available disk space")
        }
    }
    
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func generateDefaultTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "Recording \(formatter.string(from: date))"
    }
    
    private func calculateCurrentDuration() -> TimeInterval {
        guard let startTime = recordingStartTime else { return 0.0 }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Subtract paused duration
        var totalPausedDuration = pausedDuration
        if let pauseStart = pauseStartTime {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }
        
        return max(0, elapsed - totalPausedDuration)
    }
    
    // MARK: - Metering
    
    private func startMeteringTimer() {
        // Update at 60Hz for smooth visualization
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateMeters()
        }
    }
    
    private func stopMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }
    
    private func updateMeters() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return
        }
        
        recorder.updateMeters()
        
        // Get average power for channel 0 (mono recording)
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Convert from dB to linear scale (0.0 to 1.0)
        // averagePower ranges from -160 dB (silence) to 0 dB (max)
        let normalizedLevel = pow(10, averagePower / 20)
        
        // Update published properties
        _audioLevel = max(0.0, min(1.0, normalizedLevel))
        _duration = calculateCurrentDuration()
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            logger.error("Audio recorder finished unsuccessfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            logger.error("Audio recorder encode error: \(error.localizedDescription)")
        }
    }
}
