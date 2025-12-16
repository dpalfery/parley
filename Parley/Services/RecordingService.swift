//
//  RecordingService.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import AVFoundation
import UIKit
import os.log

/// Implementation of RecordingServiceProtocol for audio recording management using AVAudioEngine
final class RecordingService: NSObject, RecordingServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private var _recordingState: RecordingState = .idle
    @Published private var _audioLevel: Float = 0.0
    @Published private var _duration: TimeInterval = 0.0
    
    var recordingState: Published<RecordingState>.Publisher { $_recordingState }
    var audioLevel: Published<Float>.Publisher { $_audioLevel }
    var duration: Published<TimeInterval>.Publisher { $_duration }
    
    // MARK: - Audio Buffer Publisher
    
    private let _audioBufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()
    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> { _audioBufferSubject.eraseToAnyPublisher() }
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
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
    
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        let category: AVAudioSession.Category = .playAndRecord
        let mode: AVAudioSession.Mode = .measurement // Measurement mode often best for speech recog
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
        
        if shouldEnableBluetoothHFP(for: audioSession) {
            options.insert(.allowBluetoothHFP)
        }
        
        do {
            try audioSession.setCategory(category, mode: mode, options: options)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("Audio session configured successfully")
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
            throw RecordingError.audioSessionConfigurationFailed
        }
    }

    private func shouldEnableBluetoothHFP(for session: AVAudioSession) -> Bool {
        guard let inputs = session.availableInputs else { return false }
        return inputs.contains { $0.portType == .bluetoothHFP }
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            logger.info("Audio session deactivated")
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
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
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            logger.info("Audio session interrupted")
            if _recordingState == .recording {
                Task { try? await pauseRecording() }
            }
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                logger.info("Audio session interruption ended, should resume")
                try? configureAudioSession()
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - RecordingServiceProtocol Implementation
    
    func startRecording(quality: AudioQuality) async throws -> RecordingSession {
        logger.info("🎤 startRecording() entered")

        guard _recordingState == .idle else {
            throw RecordingError.recordingInProgress
        }

        try await requestMicrophonePermission()
        try configureAudioSession()
        try checkDiskSpace()
        
        let sessionId = UUID()
        let audioURL = try createAudioFileURL(for: sessionId)
        
        let session = RecordingSession(
            id: sessionId,
            startTime: Date(),
            quality: quality,
            audioFileURL: audioURL
        )
        currentSession = session
        
        // Setup AVAudioEngine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { throw RecordingError.audioEngineFailure }
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Setup Audio File for writing
        // Note: AVAudioFile handles the file format. We use the input format settings.
        // To respect 'quality', we might need to convert, but for MVP we use native input format
        // to ensure best transcription results and simplify the pipeline.
        // Saving as uncompressed or high-quality CAF/M4A is safer for transcription.
        
        do {
            let settings = format.settings
            audioFile = try AVAudioFile(forWriting: audioURL, settings: settings)
        } catch {
            logger.error("Failed to create audio file: \(error.localizedDescription)")
            throw RecordingError.audioEngineFailure
        }
        
        // Install Tap
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // 1. Write to file
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                self.logger.error("Error writing audio buffer: \(error)")
            }
            
            // 2. Calculate levels for metering
            self.calculateAudioLevel(from: buffer)
            
            // 3. Publish buffer for transcription
            self._audioBufferSubject.send(buffer)
        }
        
        do {
            try audioEngine.start()
            _recordingState = .recording
            recordingStartTime = Date()
            pausedDuration = 0.0
            pauseResumeMarkers = []
            
            // Start duration timer
            startDurationTimer()
            
            logger.info("Recording started with AVAudioEngine")
            return session
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            throw RecordingError.audioEngineFailure
        }
    }
    
    func pauseRecording() async throws {
        guard _recordingState == .recording, let engine = audioEngine, engine.isRunning else {
            throw RecordingError.noActiveRecording
        }
        
        engine.pause()
        
        let currentDuration = calculateCurrentDuration()
        pauseStartTime = Date()
        pauseResumeMarkers.append((timestamp: currentDuration, isPause: true))
        
        _recordingState = .paused
        logger.info("Recording paused")
    }
    
    func resumeRecording() async throws {
        guard _recordingState == .paused, let engine = audioEngine else {
            throw RecordingError.noActiveRecording
        }
        
        if let pauseStart = pauseStartTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        
        let currentDuration = calculateCurrentDuration()
        pauseResumeMarkers.append((timestamp: currentDuration, isPause: false))
        
        try engine.start()
        _recordingState = .recording
        logger.info("Recording resumed")
    }
    
    func stopRecording() async throws -> Recording {
        guard _recordingState == .recording || _recordingState == .paused else {
            throw RecordingError.noActiveRecording
        }
        
        guard let engine = audioEngine, let session = currentSession else {
            throw RecordingError.noActiveRecording
        }
        
        _recordingState = .processing
        stopDurationTimer()
        
        // Stop engine and remove tap
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        
        // Close file (setting to nil releases it)
        audioFile = nil
        audioEngine = nil
        
        let finalDuration = calculateCurrentDuration()
        let fileSize = try getFileSize(at: session.audioFileURL)
        
        let recording = Recording(
            id: session.id,
            title: generateDefaultTitle(for: session.startTime),
            date: session.startTime,
            duration: finalDuration,
            audioFileURL: session.audioFileURL,
            transcript: [],
            speakers: [],
            tags: [],
            notes: [],
            fileSize: fileSize,
            isSynced: false,
            lastModified: Date()
        )
        
        currentSession = nil
        recordingStartTime = nil
        pausedDuration = 0.0
        pauseStartTime = nil
        
        deactivateAudioSession()
        
        _recordingState = .idle
        _audioLevel = 0.0
        _duration = 0.0
        
        logger.info("Recording stopped. Duration: \(finalDuration)")
        return recording
    }
    
    func cancelRecording() async throws {
        guard _recordingState == .recording || _recordingState == .paused else {
            throw RecordingError.noActiveRecording
        }
        
        stopDurationTimer()
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil // Closes file
        
        // Delete file
        if let url = currentSession?.audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        currentSession = nil
        recordingStartTime = nil
        pausedDuration = 0.0
        pauseStartTime = nil
        
        deactivateAudioSession()
        
        _recordingState = .idle
        _audioLevel = 0.0
        _duration = 0.0
        
        logger.info("Recording cancelled")
    }
    
    // MARK: - Helper Methods
    
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        
        var sum: Float = 0
        for value in channelDataArray {
            sum += value * value
        }
        
        let rms = sqrt(sum / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        
        // Normalize
        let normalizedLevel = pow(10, avgPower / 20)
        let clampedLevel = max(0.0, min(1.0, normalizedLevel))
        
        DispatchQueue.main.async {
            self._audioLevel = clampedLevel
        }
    }
    
    private func startDurationTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.meteringTimer?.invalidate()
            self?.meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self._duration = self.calculateCurrentDuration()
            }
        }
    }
    
    private func stopDurationTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.meteringTimer?.invalidate()
            self?.meteringTimer = nil
        }
    }
    
    // Copy existing helpers
    private func createAudioFileURL(for id: UUID) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        let sessionPath = recordingsPath.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: sessionPath, withIntermediateDirectories: true)
        return sessionPath.appendingPathComponent(RecordingAudioConfig.audioFileName)
    }
    
    private func checkDiskSpace() throws {
        guard let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw RecordingError.diskSpaceInsufficient
        }
        let values = try path.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let capacity = values.volumeAvailableCapacityForImportantUsage, capacity < 100 * 1024 * 1024 {
            throw RecordingError.diskSpaceInsufficient
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
        var totalPausedDuration = pausedDuration
        if let pauseStart = pauseStartTime {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }
        return max(0, elapsed - totalPausedDuration)
    }
}
