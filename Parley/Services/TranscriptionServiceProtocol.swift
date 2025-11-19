//
//  TranscriptionServiceProtocol.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import Foundation
import Combine
import AVFoundation

/// Protocol defining the transcription service interface for speech-to-text conversion
protocol TranscriptionServiceProtocol {
    /// Publisher for streaming transcript segments as they are generated
    var transcriptSegments: Published<[TranscriptSegment]>.Publisher { get }
    
    /// Starts transcription from a recorded audio file
    /// - Parameter audioURL: URL of the audio file to transcribe
    /// - Throws: TranscriptionError if transcription cannot be started
    func startTranscription(audioURL: URL) async throws
    
    /// Starts real-time transcription from live audio buffer
    /// - Parameter audioBuffer: Audio buffer containing live audio data
    /// - Throws: TranscriptionError if live transcription cannot be started
    func startLiveTranscription(audioBuffer: AVAudioPCMBuffer) async throws
    
    /// Stops the current transcription process
    func stopTranscription() async
    
    /// Retrieves the complete transcript generated so far
    /// - Returns: Array of all transcript segments
    func getFullTranscript() async -> [TranscriptSegment]
}
