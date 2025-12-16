//
//  TranscriptionService.swift
//  Parley
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

    /// Latest segments for the current recognition window/utterance.
    /// This gets overwritten on each partial result.
    private var uncommittedSegments: [TranscriptSegment] = []

    /// Tracks the last raw (Speech-framework relative) end time we've seen.
    /// If this jumps backwards significantly, Speech has started a new block and we need to advance the offset.
    private var lastRawEndTimestamp: TimeInterval = 0.0

    private let timestampResetThreshold: TimeInterval = 1.0
    
    private let logger = Logger(subsystem: "com.meetingrecorder.app", category: "TranscriptionService")

    private struct WordSegment {
        let timestamp: TimeInterval
        let duration: TimeInterval
        let substring: String
        let confidence: Float
    }
    
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
        committedSegments = []
        uncommittedSegments = []
        recordingStartTime = Date()
        currentSegmentStartTime = 0.0
        lastRawEndTimestamp = 0.0
        
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
        uncommittedSegments = []
        recordingStartTime = Date()
        currentSegmentStartTime = 0.0
        lastRawEndTimestamp = 0.0
        
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

        let finalSegments = (committedSegments + uncommittedSegments).sorted { $0.timestamp < $1.timestamp }
        await MainActor.run {
            self._transcriptSegments = finalSegments
        }
    }
    
    func getFullTranscript() async -> [TranscriptSegment] {
        return (committedSegments + uncommittedSegments).sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Helper Methods
    
    /// Processes transcription results and converts them to transcript segments
    private func processTranscriptionResult(_ result: SFSpeechRecognitionResult, isFinal: Bool) {
        guard recordingStartTime != nil else { return }
        
        // Get the best transcription
        let transcription = result.bestTranscription

        let words: [WordSegment] = transcription.segments.map {
            WordSegment(timestamp: $0.timestamp, duration: $0.duration, substring: $0.substring, confidence: $0.confidence)
        }

        // Detect Speech "block" reset (timestamps jump backwards) and advance the global offset.
        if let last = words.last {
            let rawEnd = last.timestamp + last.duration
            if rawEnd < lastRawEndTimestamp - timestampResetThreshold {
                commitUncommittedSegments()
                currentSegmentStartTime = endTime(of: committedSegments)
                lastRawEndTimestamp = 0.0
            }
            lastRawEndTimestamp = max(lastRawEndTimestamp, rawEnd)
        }

        let newSegments = buildTranscriptSegments(from: words, offset: currentSegmentStartTime)
        // Overwrite the current uncommitted window with the latest partial result.
        uncommittedSegments = newSegments

        // Merge committed + current window for display and saving.
        let allSegments = (committedSegments + uncommittedSegments).sorted { $0.timestamp < $1.timestamp }

        // If Speech finalizes a block, commit it so the next block doesn't overwrite earlier text.
        if isFinal {
            commitUncommittedSegments()
            currentSegmentStartTime = endTime(of: committedSegments)
            lastRawEndTimestamp = 0.0
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

    private func buildTranscriptSegments(from words: [WordSegment], offset: TimeInterval) -> [TranscriptSegment] {
        guard !words.isEmpty else { return [] }

        var segments: [TranscriptSegment] = []
        var currentPhraseWords: [WordSegment] = []
        var currentPhraseStartTime: TimeInterval?

        // Simple heuristic: break phrase if gap between words is > 0.8s
        let pauseThreshold: TimeInterval = 0.8

        for word in words {
            if let lastWord = currentPhraseWords.last {
                let gap = word.timestamp - (lastWord.timestamp + lastWord.duration)
                if gap > pauseThreshold {
                    if let start = currentPhraseStartTime, !currentPhraseWords.isEmpty {
                        segments.append(makePhraseSegment(words: currentPhraseWords, start: start, offset: offset))
                    }
                    currentPhraseWords = []
                    currentPhraseStartTime = nil
                }
            }

            if currentPhraseWords.isEmpty {
                currentPhraseStartTime = word.timestamp
            }
            currentPhraseWords.append(word)
        }

        if let start = currentPhraseStartTime, !currentPhraseWords.isEmpty {
            segments.append(makePhraseSegment(words: currentPhraseWords, start: start, offset: offset))
        }

        return segments
    }

    private func makePhraseSegment(words: [WordSegment], start: TimeInterval, offset: TimeInterval) -> TranscriptSegment {
        let text = words.map { $0.substring }.joined(separator: " ")
        let duration = (words.last?.timestamp ?? 0) + (words.last?.duration ?? 0) - start
        let confidence = words.map { $0.confidence }.reduce(0, +) / Float(words.count)
        return TranscriptSegment(
            id: stableID(for: offset + start),
            text: text,
            timestamp: offset + start,
            duration: duration,
            confidence: confidence,
            speakerID: "Speaker 1",
            isEdited: false
        )
    }

    private func commitUncommittedSegments() {
        guard !uncommittedSegments.isEmpty else { return }
        committedSegments.append(contentsOf: uncommittedSegments)
        committedSegments.sort { $0.timestamp < $1.timestamp }
        uncommittedSegments = []
    }

    private func endTime(of segments: [TranscriptSegment]) -> TimeInterval {
        segments.map { $0.timestamp + $0.duration }.max() ?? 0.0
    }

    @MainActor
    func _testIngest(wordSegments: [(timestamp: TimeInterval, duration: TimeInterval, text: String, confidence: Float)], isFinal: Bool) {
        let words = wordSegments.map { WordSegment(timestamp: $0.timestamp, duration: $0.duration, substring: $0.text, confidence: $0.confidence) }

        let newSegments = buildTranscriptSegments(from: words, offset: currentSegmentStartTime)
        uncommittedSegments = newSegments
        let allSegments = (committedSegments + uncommittedSegments).sorted { $0.timestamp < $1.timestamp }

        if isFinal {
            commitUncommittedSegments()
            currentSegmentStartTime = endTime(of: committedSegments)
            lastRawEndTimestamp = 0.0
        }

        _transcriptSegments = allSegments
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

        // Snapshot current segments to committed history and advance offset.
        commitUncommittedSegments()
        currentSegmentStartTime = endTime(of: committedSegments)
        lastRawEndTimestamp = 0.0
        
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
