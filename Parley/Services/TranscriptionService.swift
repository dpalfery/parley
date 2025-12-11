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
    
    private var recordingStartTime: Date?
    private var currentSegmentStartTime: TimeInterval = 0.0
    private var segmentDuration: TimeInterval = 60.0 // 1-minute segments to avoid Speech Framework limits
    private var segmentTimer: Timer?
    
    /// Segments from previous recognition requests (accumulated history)
    private var committedSegments: [TranscriptSegment] = []
    
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
    
    func startLiveTranscription() async throws {
        // Request authorization
        try await requestSpeechRecognitionAuthorization()
        
        // Check availability
        try checkSpeechRecognitionAvailability()
        
        // Stop any existing transcription
        await stopTranscription()
        
        // Reset state
        _transcriptSegments = []
        committedSegments = []
        recordingStartTime = Date()
        currentSegmentStartTime = 0.0
        
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
        
        // Start segment timer to restart recognition every minute
        startSegmentTimer()
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
    
    func stopTranscription() async {
        logger.info("Stopping transcription")
        
        // Stop segment timer
        segmentTimer?.invalidate()
        segmentTimer = nil
        
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
        
        // Aggregate segments into phrases
        var newSegments: [TranscriptSegment] = []
        var currentPhraseWords: [SFTranscriptionSegment] = []
        var currentPhraseStartTime: TimeInterval?
        
        // Simple heuristic: break phrase if gap between words is > 0.8s
        let pauseThreshold: TimeInterval = 0.8
        
        for (index, segment) in transcription.segments.enumerated() {
            if let lastWord = currentPhraseWords.last {
                let gap = segment.timestamp - (lastWord.timestamp + lastWord.duration)
                if gap > pauseThreshold {
                    // Finalize current phrase
                    if let start = currentPhraseStartTime, !currentPhraseWords.isEmpty {
                        let text = currentPhraseWords.map { $0.substring }.joined(separator: " ")
                        let duration = (currentPhraseWords.last?.timestamp ?? 0) + (currentPhraseWords.last?.duration ?? 0) - start
                        let confidence = currentPhraseWords.map { $0.confidence }.reduce(0, +) / Float(currentPhraseWords.count)
                        
                        newSegments.append(TranscriptSegment(
                            id: stableID(for: currentSegmentStartTime + start),
                            text: text,
                            timestamp: currentSegmentStartTime + start,
                            duration: duration,
                            confidence: confidence,
                            speakerID: "Speaker 1", // Placeholder for diarization
                            isEdited: false
                        ))
                    }
                    // Start new phrase
                    currentPhraseWords = []
                    currentPhraseStartTime = nil
                }
            }
            
            if currentPhraseWords.isEmpty {
                currentPhraseStartTime = segment.timestamp
            }
            currentPhraseWords.append(segment)
        }
        
        // Handle the active (last) phrase
        if let start = currentPhraseStartTime, !currentPhraseWords.isEmpty {
            let text = currentPhraseWords.map { $0.substring }.joined(separator: " ")
            let duration = (currentPhraseWords.last?.timestamp ?? 0) + (currentPhraseWords.last?.duration ?? 0) - start
            let confidence = currentPhraseWords.map { $0.confidence }.reduce(0, +) / Float(currentPhraseWords.count)
            
            newSegments.append(TranscriptSegment(
                id: stableID(for: currentSegmentStartTime + start),
                text: text,
                timestamp: currentSegmentStartTime + start,
                duration: duration,
                confidence: confidence,
                speakerID: "Speaker 1", // Placeholder
                isEdited: false
            ))
        }
        
        // Update published segments using consistent committedSegments approach
        // with proper thread safety and rolling buffer management

        // Merge new segments with committed segments
        var allSegments = committedSegments
        if !newSegments.isEmpty {
            allSegments.append(contentsOf: newSegments)
        }

        // Apply rolling buffer cleanup - keep only last 5 minutes (300 seconds)
        if let lastTimestamp = newSegments.last?.timestamp ?? allSegments.last?.timestamp {
            let threshold = lastTimestamp - 300.0
            if threshold > 0 {
                allSegments.removeAll { $0.timestamp < threshold }
            }
        }

        // Update published segments on main thread for thread safety
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Only update if we have content to show, or if it's the very start
            if !allSegments.isEmpty || (self.committedSegments.isEmpty && newSegments.isEmpty) {
                self._transcriptSegments = allSegments
            }

            if isFinal {
                self.logger.info("Finalized \(newSegments.count) segments for current window. Total visible: \(allSegments.count)")
            }
        }
    }
    
    /// Generates a deterministic UUID based on timestamp to prevent UI flickering
    private func stableID(for timestamp: TimeInterval) -> UUID {
        // Create a deterministic UUID from the timestamp (Double)
        // We use the bit pattern of the timestamp to form the first 8 bytes
        let bits = timestamp.bitPattern
        let uuid: uuid_t = (
            UInt8((bits >> 56) & 0xff),
            UInt8((bits >> 48) & 0xff),
            UInt8((bits >> 40) & 0xff),
            UInt8((bits >> 32) & 0xff),
            UInt8((bits >> 24) & 0xff),
            UInt8((bits >> 16) & 0xff),
            UInt8((bits >> 8) & 0xff),
            UInt8(bits & 0xff),
            0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89
        )
        return UUID(uuid: uuid)
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
        
        // Snapshot current segments to committed history
        committedSegments = _transcriptSegments
        
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
