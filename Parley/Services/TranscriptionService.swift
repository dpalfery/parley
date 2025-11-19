//
//  TranscriptionService.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import AVFoundation
import Speech
import os.log

/// Implementation of TranscriptionServiceProtocol for speech-to-text conversion
final class TranscriptionService: TranscriptionServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private var _transcriptSegments: [TranscriptSegment] = []
    
    var transcriptSegments: Published<[TranscriptSegment]>.Publisher { $_transcriptSegments }
    
    // MARK: - Private Properties
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    private var recordingStartTime: Date?
    private var currentSegmentStartTime: TimeInterval = 0.0
    private var segmentDuration: TimeInterval = 60.0 // 1-minute segments to avoid Speech Framework limits
    private var segmentTimer: Timer?
    
    private let logger = Logger(subsystem: "com.meetingrecorder.app", category: "TranscriptionService")
    
    // MARK: - Initialization
    
    init() {
        setupSpeechRecognizer()
    }
    
    deinit {
        segmentTimer?.invalidate()
    }
    
    // MARK: - Speech Framework Setup
    
    /// Initializes the speech recognizer with device locale
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        
        if speechRecognizer == nil {
            logger.error("Speech recognizer not available for locale: \(Locale.current.identifier)")
        } else {
            logger.info("Speech recognizer initialized for locale: \(Locale.current.identifier)")
        }
    }
    
    /// Requests speech recognition authorization
    private func requestSpeechRecognitionAuthorization() async throws {
        let status = SFSpeechRecognizer.authorizationStatus()
        
        switch status {
        case .authorized:
            return
        case .denied, .restricted:
            throw TranscriptionError.speechRecognitionPermissionDenied
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            if !granted {
                throw TranscriptionError.speechRecognitionPermissionDenied
            }
        @unknown default:
            throw TranscriptionError.speechRecognitionPermissionDenied
        }
    }
    
    /// Checks if speech recognition is available
    private func checkSpeechRecognitionAvailability() throws {
        guard let recognizer = speechRecognizer else {
            throw TranscriptionError.speechRecognitionUnavailable
        }
        
        guard recognizer.isAvailable else {
            throw TranscriptionError.speechRecognitionUnavailable
        }
    }
    
    // MARK: - TranscriptionServiceProtocol Implementation
    
    func startTranscription(audioURL: URL) async throws {
        // Request authorization
        try await requestSpeechRecognitionAuthorization()
        
        // Check availability
        try checkSpeechRecognitionAvailability()
        
        // Stop any existing transcription
        await stopTranscription()
        
        // Reset state
        _transcriptSegments = []
        recordingStartTime = Date()
        currentSegmentStartTime = 0.0
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Use on-device processing
        
        guard let recognizer = speechRecognizer else {
            throw TranscriptionError.speechRecognitionUnavailable
        }
        
        logger.info("Starting transcription from audio file: \(audioURL.lastPathComponent)")
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Recognition error: \(error.localizedDescription)")
                return
            }
            
            guard let result = result else { return }
            
            // Process transcription result
            self.processTranscriptionResult(result, isFinal: result.isFinal)
        }
    }
    
    func startLiveTranscription(audioBuffer: AVAudioPCMBuffer) async throws {
        // Request authorization
        try await requestSpeechRecognitionAuthorization()
        
        // Check availability
        try checkSpeechRecognitionAvailability()
        
        // Stop any existing transcription
        await stopTranscription()
        
        // Reset state
        _transcriptSegments = []
        recordingStartTime = Date()
        currentSegmentStartTime = 0.0
        
        // Create audio engine if needed
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Use on-device processing
        recognitionRequest = request
        
        guard let recognizer = speechRecognizer else {
            throw TranscriptionError.speechRecognitionUnavailable
        }
        
        logger.info("Starting live transcription")
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Live recognition error: \(error.localizedDescription)")
                
                // Check if we hit the 1-minute limit
                if (error as NSError).code == 216 {
                    // Recognition limit exceeded - restart for continuous transcription
                    Task {
                        await self.restartLiveTranscription()
                    }
                }
                return
            }
            
            guard let result = result else { return }
            
            // Process transcription result
            self.processTranscriptionResult(result, isFinal: result.isFinal)
        }
        
        // Append the audio buffer
        recognitionRequest?.append(audioBuffer)
        
        // Start segment timer to restart recognition every minute
        startSegmentTimer()
    }
    
    func stopTranscription() async {
        logger.info("Stopping transcription")
        
        // Stop segment timer
        segmentTimer?.invalidate()
        segmentTimer = nil
        
        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Cancel recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Reset state
        recordingStartTime = nil
    }
    
    func getFullTranscript() async -> [TranscriptSegment] {
        return _transcriptSegments
    }
    
    // MARK: - Helper Methods
    
    /// Processes transcription results and converts them to transcript segments
    private func processTranscriptionResult(_ result: SFSpeechRecognitionResult, isFinal: Bool) {
        guard recordingStartTime != nil else { return }
        
        // Get the best transcription
        let transcription = result.bestTranscription
        
        // Process each segment
        var newSegments: [TranscriptSegment] = []
        
        for (index, segment) in transcription.segments.enumerated() {
            // Calculate timestamp relative to recording start
            let segmentTimestamp = currentSegmentStartTime + segment.timestamp
            
            // Calculate duration (use next segment's timestamp or remaining time)
            let duration: TimeInterval
            if index < transcription.segments.count - 1 {
                duration = transcription.segments[index + 1].timestamp - segment.timestamp
            } else {
                // For last segment, estimate duration based on text length
                duration = Double(segment.substring.count) * 0.05 // ~50ms per character
            }
            
            // Get confidence score (average of all alternatives)
            let confidence = segment.confidence
            
            // Create transcript segment
            // Note: Speaker ID will be assigned by SpeakerService later
            let transcriptSegment = TranscriptSegment(
                id: UUID(),
                text: segment.substring,
                timestamp: segmentTimestamp,
                duration: duration,
                confidence: confidence,
                speakerID: "speaker-unknown",
                isEdited: false
            )
            
            newSegments.append(transcriptSegment)
        }
        
        // Update published segments
        if isFinal {
            // Append final segments
            _transcriptSegments.append(contentsOf: newSegments)
            logger.info("Added \(newSegments.count) final transcript segments")
        } else {
            // For partial results, replace temporary segments
            // Remove any temporary segments from current time window
            _transcriptSegments.removeAll { segment in
                segment.timestamp >= currentSegmentStartTime && segment.speakerID == "speaker-unknown"
            }
            _transcriptSegments.append(contentsOf: newSegments)
        }
    }
    
    /// Starts a timer to restart recognition every minute to avoid Speech Framework limits
    private func startSegmentTimer() {
        segmentTimer?.invalidate()
        
        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: true) { [weak self] _ in
            Task {
                await self?.restartLiveTranscription()
            }
        }
    }
    
    /// Restarts live transcription for continuous long recordings
    private func restartLiveTranscription() async {
        logger.info("Restarting live transcription for next segment")
        
        // Update segment start time
        currentSegmentStartTime += segmentDuration
        
        // End current request
        recognitionRequest?.endAudio()
        
        // Cancel current task
        recognitionTask?.cancel()
        
        // Create new recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request
        
        guard let recognizer = speechRecognizer else {
            logger.error("Speech recognizer unavailable during restart")
            return
        }
        
        // Start new recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Recognition error after restart: \(error.localizedDescription)")
                
                // Check if we hit the limit again
                if (error as NSError).code == 216 {
                    Task {
                        await self.restartLiveTranscription()
                    }
                }
                return
            }
            
            guard let result = result else { return }
            
            // Process transcription result
            self.processTranscriptionResult(result, isFinal: result.isFinal)
        }
    }
}
