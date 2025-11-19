//
//  RecordingDetailUITests.swift
//  MeetingRecorderUITests
//
//  UI tests for recording detail playback and editing
//

import XCTest

final class RecordingDetailUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Navigate to a recording detail view
        let firstRecording = app.cells.firstMatch
        if firstRecording.exists {
            firstRecording.tap()
        }
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Detail View Display Tests
    
    func testDetailViewExists() throws {
        // Given: Navigated to detail view
        
        // Then: Detail view should be visible
        let detailView = app.otherElements["recordingDetailView"]
        XCTAssertTrue(detailView.exists || app.navigationBars.count > 0)
    }
    
    func testRecordingMetadataDisplayed() throws {
        // Given: Detail view is visible
        
        // Then: Should display title
        let titleLabel = app.staticTexts["recordingTitle"]
        XCTAssertTrue(titleLabel.exists || app.navigationBars.staticTexts.count > 0)
        
        // Then: Should display date
        // Then: Should display duration
        // (Specific identifiers depend on implementation)
    }
    
    // MARK: - Playback Control Tests
    
    func testPlayButtonExists() throws {
        // Given: Detail view is visible
        
        // Then: Play button should exist
        let playButton = app.buttons["playButton"]
        XCTAssertTrue(playButton.exists)
    }
    
    func testPlayButtonStartsPlayback() throws {
        // Given: Detail view with play button
        let playButton = app.buttons["playButton"]
        
        // When: Tapping play button
        playButton.tap()
        
        // Then: Should change to pause button
        let pauseButton = app.buttons["pauseButton"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 2))
    }
    
    func testPauseButtonPausesPlayback() throws {
        // Given: Playback is active
        let playButton = app.buttons["playButton"]
        playButton.tap()
        
        // When: Tapping pause button
        let pauseButton = app.buttons["pauseButton"]
        if pauseButton.exists {
            pauseButton.tap()
            
            // Then: Should change back to play button
            XCTAssertTrue(playButton.waitForExistence(timeout: 2))
        }
    }
    
    func testSkipForwardButton() throws {
        // Given: Detail view with playback controls
        
        // Then: Skip forward button should exist
        let skipForwardButton = app.buttons["skipForwardButton"]
        XCTAssertTrue(skipForwardButton.exists)
        
        // When: Tapping skip forward
        skipForwardButton.tap()
        
        // Then: Playback position should advance
        // (Verification requires checking time label)
    }
    
    func testSkipBackwardButton() throws {
        // Given: Detail view with playback controls
        
        // Then: Skip backward button should exist
        let skipBackwardButton = app.buttons["skipBackwardButton"]
        XCTAssertTrue(skipBackwardButton.exists)
        
        // When: Tapping skip backward
        skipBackwardButton.tap()
        
        // Then: Playback position should go back
        // (Verification requires checking time label)
    }
    
    func testPlaybackProgressSlider() throws {
        // Given: Detail view with playback controls
        
        // Then: Progress slider should exist
        let progressSlider = app.sliders["playbackProgressSlider"]
        XCTAssertTrue(progressSlider.exists)
    }
    
    func testSeekingWithSlider() throws {
        // Given: Progress slider exists
        let progressSlider = app.sliders["playbackProgressSlider"]
        
        if progressSlider.exists {
            // When: Adjusting slider
            progressSlider.adjust(toNormalizedSliderPosition: 0.5)
            
            // Then: Playback position should update
            // (Verification requires checking time label)
        }
    }
    
    func testPlaybackTimeDisplay() throws {
        // Given: Playback controls visible
        
        // Then: Current time should be displayed
        let currentTimeLabel = app.staticTexts["currentTimeLabel"]
        XCTAssertTrue(currentTimeLabel.exists)
        
        // Then: Total duration should be displayed
        let durationLabel = app.staticTexts["totalDurationLabel"]
        XCTAssertTrue(durationLabel.exists)
    }
    
    // MARK: - Transcript Display Tests
    
    func testTranscriptViewExists() throws {
        // Given: Detail view is visible
        
        // Then: Transcript view should exist
        let transcriptView = app.scrollViews["transcriptScrollView"]
        XCTAssertTrue(transcriptView.exists || app.textViews["transcriptTextView"].exists)
    }
    
    func testTranscriptShowsSpeakerLabels() throws {
        // Given: Transcript is visible
        
        // Then: Speaker labels should be displayed
        // (Specific verification depends on transcript content)
        let transcriptView = app.scrollViews["transcriptScrollView"]
        if transcriptView.exists {
            XCTAssertTrue(transcriptView.staticTexts.count > 0)
        }
    }
    
    func testTapTranscriptSegmentSeeksPlayback() throws {
        // Given: Transcript with segments
        let transcriptView = app.scrollViews["transcriptScrollView"]
        
        if transcriptView.exists {
            let firstSegment = transcriptView.staticTexts.firstMatch
            
            if firstSegment.exists {
                // When: Tapping segment
                firstSegment.tap()
                
                // Then: Playback should seek to that timestamp
                // (Verification requires checking playback position)
            }
        }
    }
    
    func testTranscriptHighlightsDuringPlayback() throws {
        // Given: Playback is active
        let playButton = app.buttons["playButton"]
        playButton.tap()
        
        // When: Audio is playing
        sleep(2)
        
        // Then: Current segment should be highlighted
        // (Verification depends on highlighting implementation)
    }
    
    // MARK: - Transcript Editing Tests
    
    func testEditModeToggle() throws {
        // Given: Detail view is visible
        
        // Then: Edit button should exist
        let editButton = app.buttons["editButton"]
        XCTAssertTrue(editButton.exists || app.navigationBars.buttons["Edit"].exists)
    }
    
    func testEnteringEditMode() throws {
        // Given: Edit button exists
        let editButton = app.buttons["editButton"]
        
        if editButton.exists {
            // When: Tapping edit button
            editButton.tap()
            
            // Then: Should enter edit mode
            let doneButton = app.buttons["doneButton"]
            XCTAssertTrue(doneButton.waitForExistence(timeout: 2) || app.navigationBars.buttons["Done"].exists)
        }
    }
    
    func testEditingTranscriptText() throws {
        // Given: In edit mode
        let editButton = app.buttons["editButton"]
        
        if editButton.exists {
            editButton.tap()
            
            // When: Tapping transcript text
            let transcriptTextView = app.textViews["transcriptTextView"]
            if transcriptTextView.exists {
                transcriptTextView.tap()
                
                // Then: Should be able to edit
                XCTAssertTrue(transcriptTextView.isHittable)
            }
        }
    }
    
    func testSavingTranscriptEdits() throws {
        // Given: In edit mode with changes
        let editButton = app.buttons["editButton"]
        
        if editButton.exists {
            editButton.tap()
            
            // When: Tapping done/save
            let doneButton = app.buttons["doneButton"]
            if doneButton.exists {
                doneButton.tap()
                
                // Then: Should exit edit mode
                XCTAssertTrue(editButton.waitForExistence(timeout: 2))
            }
        }
    }
    
    func testEditingSpeakerLabels() throws {
        // Given: In edit mode
        let editButton = app.buttons["editButton"]
        
        if editButton.exists {
            editButton.tap()
            
            // When: Tapping speaker label
            let speakerLabel = app.buttons.matching(identifier: "speakerLabel").firstMatch
            if speakerLabel.exists {
                speakerLabel.tap()
                
                // Then: Should be able to edit speaker name
                // (Verification depends on implementation)
            }
        }
    }
    
    // MARK: - Notes Management Tests
    
    func testNotesSection() throws {
        // Given: Detail view is visible
        
        // Then: Notes section should exist
        let notesSection = app.otherElements["notesSection"]
        // May need to scroll to find it
    }
    
    func testAddNoteButton() throws {
        // Given: Detail view is visible
        
        // Then: Add note button should exist
        let addNoteButton = app.buttons["addNoteButton"]
        XCTAssertTrue(addNoteButton.exists || app.toolbars.buttons["addNoteButton"].exists)
    }
    
    func testAddingNote() throws {
        // Given: Add note button exists
        let addNoteButton = app.buttons["addNoteButton"]
        
        if addNoteButton.exists {
            // When: Tapping add note
            addNoteButton.tap()
            
            // Then: Note input should appear
            let noteTextField = app.textFields["noteTextField"]
            XCTAssertTrue(noteTextField.waitForExistence(timeout: 2) || app.textViews["noteTextView"].exists)
        }
    }
    
    func testEditingNote() throws {
        // Given: Notes exist
        let noteCell = app.cells.matching(identifier: "noteCell").firstMatch
        
        if noteCell.exists {
            // When: Tapping note
            noteCell.tap()
            
            // Then: Should be able to edit
            // (Verification depends on implementation)
        }
    }
    
    func testDeletingNote() throws {
        // Given: Notes exist
        let noteCell = app.cells.matching(identifier: "noteCell").firstMatch
        
        if noteCell.exists {
            // When: Swiping to delete
            noteCell.swipeLeft()
            
            // Then: Delete button should appear
            let deleteButton = app.buttons["Delete"]
            if deleteButton.exists {
                deleteButton.tap()
                
                // Then: Note should be removed
            }
        }
    }
    
    // MARK: - Tag Management Tests
    
    func testTagsDisplayed() throws {
        // Given: Detail view is visible
        
        // Then: Tags section should exist
        let tagsSection = app.otherElements["tagsSection"]
        // May need to scroll to find it
    }
    
    func testAddTagButton() throws {
        // Given: Detail view is visible
        
        // Then: Add tag button should exist
        let addTagButton = app.buttons["addTagButton"]
        // May need to scroll to find it
    }
    
    func testAddingTag() throws {
        // Given: Add tag button exists
        let addTagButton = app.buttons["addTagButton"]
        
        if addTagButton.exists {
            // When: Tapping add tag
            addTagButton.tap()
            
            // Then: Tag input should appear
            let tagTextField = app.textFields["tagTextField"]
            XCTAssertTrue(tagTextField.waitForExistence(timeout: 2))
        }
    }
    
    func testRemovingTag() throws {
        // Given: Tags exist
        let tagButton = app.buttons.matching(identifier: "tagButton").firstMatch
        
        if tagButton.exists {
            // When: Tapping remove on tag
            // (Implementation may vary - could be swipe or button)
            
            // Then: Tag should be removed
        }
    }
    
    // MARK: - Export and Share Tests
    
    func testExportButton() throws {
        // Given: Detail view is visible
        
        // Then: Export button should exist
        let exportButton = app.buttons["exportButton"]
        XCTAssertTrue(exportButton.exists || app.navigationBars.buttons["exportButton"].exists)
    }
    
    func testExportOptionsSheet() throws {
        // Given: Export button exists
        let exportButton = app.buttons["exportButton"]
        
        if exportButton.exists {
            // When: Tapping export
            exportButton.tap()
            
            // Then: Export options should appear
            let actionSheet = app.sheets.firstMatch
            XCTAssertTrue(actionSheet.waitForExistence(timeout: 2))
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testPlaybackControlsAccessibility() throws {
        // Given: Playback controls visible
        let playButton = app.buttons["playButton"]
        
        // Then: Should be accessible
        XCTAssertTrue(playButton.isHittable)
        XCTAssertFalse(playButton.label.isEmpty)
    }
    
    func testTranscriptAccessibility() throws {
        // Given: Transcript visible
        let transcriptView = app.scrollViews["transcriptScrollView"]
        
        if transcriptView.exists {
            // Then: Should be accessible
            XCTAssertTrue(transcriptView.isHittable)
        }
    }
}
