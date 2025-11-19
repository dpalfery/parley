import Foundation
import AVFoundation

/// Centralized configuration for recording audio formats and filenames
enum RecordingAudioConfig {
    /// File extension for persisted recordings based on the current environment
    static var audioFileExtension: String {
#if targetEnvironment(simulator)
        return "caf"
#else
        return "m4a"
#endif
    }
    
    /// Canonical filename for stored recordings (e.g., audio.m4a or audio.caf)
    static var audioFileName: String {
        "audio.\(audioFileExtension)"
    }
    
    /// Audio recorder settings tuned for simulator/device capabilities
    /// - Parameter quality: Desired audio quality selection
    /// - Returns: Dictionary of AVAudioRecorder settings
    static func audioSettings(for quality: AudioQuality) -> [String: Any] {
#if targetEnvironment(simulator)
        return [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
#else
        return [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: quality.bitRate
        ]
#endif
    }
}
