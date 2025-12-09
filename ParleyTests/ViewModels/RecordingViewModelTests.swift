
import XCTest
import Combine
import AVFoundation
@testable import Parley

class MockRecordingService: RecordingServiceProtocol {
    @Published var _recordingState: RecordingState = .idle
    @Published var _audioLevel: Float = 0.0
    @Published var _duration: TimeInterval = 0.0
    
    var recordingState: Published<RecordingState>.Publisher { $_recordingState }
    var audioLevel: Published<Float>.Publisher { $_audioLevel }
    var duration: Published<TimeInterval>.Publisher { $_duration }
    
    var audioBufferPublisher: AnyPublisher<AVAudioPCMBuffer, Never> {
        PassthroughSubject<AVAudioPCMBuffer, Never>().eraseToAnyPublisher()
    }
    
    func startRecording(quality: AudioQuality) async throws -> RecordingSession {
        fatalError("Not implemented")
    }
    func pauseRecording() async throws {}
    func resumeRecording() async throws {}
    func stopRecording() async throws -> Recording {
        fatalError("Not implemented")
    }
    func cancelRecording() async throws {}
    
    func simulateAudioLevel(_ level: Float) {
        _audioLevel = level
    }
}

class MockTranscriptionService: TranscriptionServiceProtocol {
    @Published var _transcriptSegments: [TranscriptSegment] = []
    var transcriptSegments: Published<[TranscriptSegment]>.Publisher { $_transcriptSegments }
    
    func startTranscription(audioURL: URL) async throws {}
    func startLiveTranscription() async throws {}
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {}
    func stopTranscription() async {}
    func getFullTranscript() async -> [TranscriptSegment] { return [] }
}

class MockPermissionManager: PermissionManager {
    // Override init to allow instantiation without side effects if possible, 
    // but PermissionManager calls methods in init.
    // We assume AVAudioSession is safe to call in test env.
}

@MainActor
class RecordingViewModelTests: XCTestCase {
    var viewModel: RecordingViewModel!
    var mockRecordingService: MockRecordingService!
    var mockTranscriptionService: MockTranscriptionService!
    var mockPermissionManager: MockPermissionManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockRecordingService = MockRecordingService()
        mockTranscriptionService = MockTranscriptionService()
        mockPermissionManager = MockPermissionManager()
        cancellables = []
        
        viewModel = RecordingViewModel(
            recordingService: mockRecordingService,
            transcriptionService: mockTranscriptionService,
            permissionManager: mockPermissionManager
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockRecordingService = nil
        mockTranscriptionService = nil
        mockPermissionManager = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testAudioLevelTransformation() async {
        let expectation = XCTestExpectation(description: "Audio level updated")
        var receivedLevels: [Float] = []
        
        viewModel.$audioLevel
            .dropFirst() // Drop initial 0.0
            .sink { level in
                receivedLevels.append(level)
                if receivedLevels.count >= 4 { // We expect 4 updates
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Test Case 1: Silence (0.0 linear) -> Should be 0.0
        // db = -inf -> clamped to 0.0
        mockRecordingService.simulateAudioLevel(0.0)
        
        // Test Case 2: Max Volume (1.0 linear) -> Should be 1.0
        // db = 0 -> 1.0
        // Wait a bit to ensure Combine processes
        try? await Task.sleep(nanoseconds: 10_000_000)
        mockRecordingService.simulateAudioLevel(1.0)
        
        // Test Case 3: Small Signal (0.001 linear) -> -60dB -> Should be 0.0
        try? await Task.sleep(nanoseconds: 10_000_000)
        mockRecordingService.simulateAudioLevel(0.001)
        
        // Test Case 4: Moderate Signal (0.0316 linear) -> approx -30dB
        // -30dB is halfway between -60 and 0 -> Should be 0.5
        try? await Task.sleep(nanoseconds: 10_000_000)
        mockRecordingService.simulateAudioLevel(0.0316227766) 
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertEqual(receivedLevels.count, 4)
        XCTAssertEqual(receivedLevels[0], 0.0, accuracy: 0.001, "0.0 linear should be 0.0")
        XCTAssertEqual(receivedLevels[1], 1.0, accuracy: 0.001, "1.0 linear should be 1.0")
        XCTAssertEqual(receivedLevels[2], 0.0, accuracy: 0.01, "0.001 linear (-60dB) should be 0.0")
        XCTAssertEqual(receivedLevels[3], 0.5, accuracy: 0.05, "0.0316 linear (-30dB) should be approx 0.5")
    }
}
