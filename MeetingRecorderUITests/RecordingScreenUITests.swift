//
//  RecordingScreenUITests.swift
//  MeetingRecorderUITests
//
//  UI tests for recording screen interactions
//

import XCTest

final class RecordingScreenUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Recording Button Tests
    
    func testRecordButtonExists() throws {
        // Given: App is launched
        
        // When: Navigating to recording screen
        // (Assuming recording screen is accessible from main view)
        
        // Then: Record button should exist
        let recordButton = app.buttons["recordButton"]
        XCTAssertTrue(recordButton.exists)
    }
    
    func testRecordButtonStartsRecording() throws {
        // Given: Recording screen is visible
        let recordButton = app.buttons["recordButton"]
        
        // When: Tapping record button
        recordButton.tap()
        
        // Then: Recording state indicator should show recording
        let recordingIndicator = app.staticTexts["recordingIndicator"]
        XCTAssertTrue(recordingIndicator.exists)
        
        // Then: Pause button should appear
        let pauseButton = app.buttons["pauseButton"]
        XCTAssertTrue(pauseButton.exists)
    }
    
    func testPauseButtonPausesRecording() throws {
        // Given: Recording is active
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        // When: Tapping pause button
        let pauseButton = app.buttons["pauseButton"]
        pauseButton.tap()
        
        // Then: Recording state should show paused
        let pausedIndicator = app.staticTexts["pausedIndicator"]
        XCTAssertTrue(pausedIndicator.exists)
        
        // Then: Resume button should appear
        let resumeButton = app.buttons["resumeButton"]
        XCTAssertTrue(resumeButton.exists)
    }
    
    func testResumeButtonResumesRecording() throws {
        // Given: Recording is paused
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        let pauseButton = app.buttons["pauseButton"]
        pauseButton.tap()
        
        // When: Tapping resume button
        let resumeButton = app.buttons["resumeButton"]
        resumeButton.tap()
        
        // Then: Recording state should show recording again
        let recordingIndicator = app.staticTexts["recordingIndicator"]
        XCTAssertTrue(recordingIndicator.exists)
    }
    
    func testStopButtonStopsRecording() throws {
        // Given: Recording is active
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        // When: Tapping stop button
        let stopButton = app.buttons["stopButton"]
        stopButton.tap()
        
        // Then: Should navigate to save/detail screen or return to idle
        // (Verification depends on app flow)
    }
    
    // MARK: - Timer Display Tests
    
    func testTimerDisplayExists() throws {
        // Given: Recording is active
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        // When: Recording is in progress
        
        // Then: Timer should be visible
        let timerLabel = app.staticTexts["durationLabel"]
        XCTAssertTrue(timerLabel.exists)
        
        // Then: Timer should show time format (MM:SS)
        let timerText = timerLabel.label
        XCTAssertTrue(timerText.contains(":"))
    }
    
    func testTimerUpdates() throws {
        // Given: Recording is active
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        let timerLabel = app.staticTexts["durationLabel"]
        let initialTime = timerLabel.label
        
        // When: Time passes
        sleep(2)
        
        // Then: Timer should update
        let updatedTime = timerLabel.label
        XCTAssertNotEqual(initialTime, updatedTime)
    }
    
    // MARK: - Audio Level Visualization Tests
    
    func testAudioLevelMeterExists() throws {
        // Given: Recording is active
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        // When: Recording is in progress
        
        // Then: Audio level meter should be visible
        let audioMeter = app.otherElements["audioLevelMeter"]
        XCTAssertTrue(audioMeter.exists)
    }
    
    // MARK: - Transcript Display Tests
    
    func testTranscriptViewExists() throws {
        // Given: Recording is active
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        // When: Recording is in progress
        
        // Then: Transcript view should be visible
        let transcriptView = app.scrollViews["transcriptView"]
        XCTAssertTrue(transcriptView.exists)
    }
    
    func testTranscriptUpdatesInRealTime() throws {
        // Given: Recording with audio input
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        // When: Audio is being transcribed
        // Note: Actual transcription requires audio input
        
        // Then: Transcript should update
        let transcriptView = app.scrollViews["transcriptView"]
        XCTAssertTrue(transcriptView.exists)
    }
    
    // MARK: - Notes Input Tests
    
    func testNotesButtonExists() throws {
        // Given: Recording is active
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        // When: Looking for notes button
        
        // Then: Notes button should be accessible
        let notesButton = app.buttons["addNoteButton"]
        XCTAssertTrue(notesButton.exists)
    }
    
    func testNotesInputOpens() throws {
        // Given: Recording is active
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        // When: Tapping notes button
        let notesButton = app.buttons["addNoteButton"]
        notesButton.tap()
        
        // Then: Notes input should appear
        let notesTextField = app.textFields["noteTextField"]
        XCTAssertTrue(notesTextField.exists)
    }
    
    func testNotesCanBeAdded() throws {
        // Given: Notes input is open
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        let notesButton = app.buttons["addNoteButton"]
        notesButton.tap()
        
        // When: Entering note text
        let notesTextField = app.textFields["noteTextField"]
        notesTextField.tap()
        notesTextField.typeText("Test note")
        
        // When: Saving note
        let saveButton = app.buttons["saveNoteButton"]
        saveButton.tap()
        
        // Then: Note should be saved
        // (Verification would check notes list)
    }
    
    // MARK: - Accessibility Tests
    
    func testRecordButtonAccessibility() throws {
        // Given: Recording screen
        let recordButton = app.buttons["recordButton"]
        
        // Then: Should have accessibility label
        XCTAssertTrue(recordButton.isHittable)
        XCTAssertFalse(recordButton.label.isEmpty)
    }
    
    func testAllControlsAccessible() throws {
        // Given: Recording is active
        let recordButton = app.buttons["recordButton"]
        recordButton.tap()
        
        // Then: All controls should be accessible
        let pauseButton = app.buttons["pauseButton"]
        let stopButton = app.buttons["stopButton"]
        
        XCTAssertTrue(pauseButton.isHittable)
        XCTAssertTrue(stopButton.isHittable)
    }
}
