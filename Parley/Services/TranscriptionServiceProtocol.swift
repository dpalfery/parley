//
//  TranscriptionServiceProtocol.swift
//  Parley
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import AVFoundation

/// Protocol defining the transcription service interface for speech-to-text conversion
///
/// ## Threading Requirements
///
/// **CRITICAL**: The `processAudioBuffer(_:)` method requires low-latency delivery (<10ms) from the audio recording pipeline.
/// Audio buffers MUST NOT be dispatched to the main thread before calling this method, as main thread contention will cause
/// dropped buffers and transcription failures.
///
/// ### Correct Usage Pattern
/// ```swift
/// recordingService.audioBufferPublisher
///     .sink { [weak self] buffer in
///         self?.transcriptionService.processAudioBuffer(buffer)
///     }
///     .store(in: &cancellables)
/// ```
///
/// ### Incorrect Usage Pattern (DO NOT USE)
/// ```swift
/// recordingService.audioBufferPublisher
///     .receive(on: DispatchQueue.main)  // ❌ Blocks audio pipeline!
///     .sink { [weak self] buffer in
///         self?.transcriptionService.processAudioBuffer(buffer)
///     }
///     .store(in: &cancellables)
/// ```
protocol TranscriptionServiceProtocol {
    /// Publisher for streaming transcript segments as they are generated
    var transcriptSegments: Published<[TranscriptSegment]>.Publisher { get }
    
    /// Starts transcription from a recorded audio file
    /// - Parameter audioURL: URL of the audio file to transcribe
    /// - Throws: TranscriptionError if transcription cannot be started
    func startTranscription(audioURL: URL) async throws
    
    /// Starts real-time transcription session
    /// - Throws: TranscriptionError if live transcription cannot be started
    func startLiveTranscription() async throws
    
    /// Processes an audio buffer for the active live transcription session
    ///
    /// **Thread Safety**: This method is thread-safe and MUST be called on background threads
    /// to maintain low-latency buffer delivery. Do not dispatch buffers to the main thread
    /// before calling this method.
    ///
    /// - Parameter buffer: Audio buffer containing live audio data
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer)
    
    /// Stops the current transcription process
    func stopTranscription() async
    
    /// Retrieves the complete transcript generated so far
    /// - Returns: Array of all transcript segments
    func getFullTranscript() async -> [TranscriptSegment]
}