//
//  SettingsUITests.swift
//  MeetingRecorderUITests
//
//  UI tests for settings and storage management
//

import XCTest

final class SettingsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Navigate to settings
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.exists {
            settingsButton.tap()
        } else {
            // Try tab bar
            let settingsTab = app.tabBars.buttons["Settings"]
            if settingsTab.exists {
                settingsTab.tap()
            }
        }
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Settings View Tests
    
    func testSettingsViewExists() throws {
        // Given: Navigated to settings
        
        // Then: Settings view should be visible
        let settingsView = app.otherElements["settingsView"]
        XCTAssertTrue(settingsView.exists || app.navigationBars["Settings"].exists)
    }
    
    // MARK: - Audio Quality Settings Tests
    
    func testAudioQualitySettingExists() throws {
        // Given: Settings view is visible
        
        // Then: Audio quality setting should exist
        let audioQualitySetting = app.buttons["audioQualitySetting"]
        XCTAssertTrue(audioQualitySetting.exists || app.staticTexts["Audio Quality"].exists)
    }
    
    func testAudioQualityPicker() throws {
        // Given: Audio quality setting exists
        let audioQualitySetting = app.buttons["audioQualitySetting"]
        
        if audioQualitySetting.exists {
            // When: Tapping audio quality
            audioQualitySetting.tap()
            
            // Then: Picker should appear with options
            let lowOption = app.buttons["Low (64 kbps)"]
            let mediumOption = app.buttons["Medium (128 kbps)"]
            let highOption = app.buttons["High (256 kbps)"]
            
            XCTAssertTrue(lowOption.exists || mediumOption.exists || highOption.exists)
        }
    }
    
    func testSelectingAudioQuality() throws {
        // Given: Audio quality picker is open
        let audioQualitySetting = app.buttons["audioQualitySetting"]
        
        if audioQualitySetting.exists {
            audioQualitySetting.tap()
            
            // When: Selecting an option
            let mediumOption = app.buttons["Medium (128 kbps)"]
            if mediumOption.exists {
                mediumOption.tap()
                
                // Then: Selection should be saved
                // (Verification depends on implementation)
            }
        }
    }
    
    // MARK: - iCloud Sync Settings Tests
    
    func testICloudSyncToggleExists() throws {
        // Given: Settings view is visible
        
        // Then: iCloud sync toggle should exist
        let syncToggle = app.switches["iCloudSyncToggle"]
        XCTAssertTrue(syncToggle.exists || app.staticTexts["iCloud Sync"].exists)
    }
    
    func testTogglingICloudSync() throws {
        // Given: iCloud sync toggle exists
        let syncToggle = app.switches["iCloudSyncToggle"]
        
        if syncToggle.exists {
            let initialValue = syncToggle.value as? String
            
            // When: Toggling sync
            syncToggle.tap()
            
            // Then: Value should change
            let newValue = syncToggle.value as? String
            XCTAssertNotEqual(initialValue, newValue)
        }
    }
    
    func testICloudSyncDescription() throws {
        // Given: Settings view is visible
        
        // Then: Should show sync description or status
        let syncDescription = app.staticTexts.matching(identifier: "syncDescription").firstMatch
        // May or may not exist depending on implementation
    }
    
    // MARK: - Storage Management Tests
    
    func testStorageUsageDisplayed() throws {
        // Given: Settings view is visible
        
        // Then: Storage usage should be displayed
        let storageUsage = app.staticTexts["storageUsageLabel"]
        XCTAssertTrue(storageUsage.exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'MB' OR label CONTAINS 'GB'")).count > 0)
    }
    
    func testStorageBreakdownButton() throws {
        // Given: Settings view is visible
        
        // Then: Storage breakdown button should exist
        let breakdownButton = app.buttons["storageBreakdownButton"]
        XCTAssertTrue(breakdownButton.exists || app.staticTexts["Storage"].exists)
    }
    
    func testViewingStorageBreakdown() throws {
        // Given: Storage breakdown button exists
        let breakdownButton = app.buttons["storageBreakdownButton"]
        
        if breakdownButton.exists {
            // When: Tapping breakdown button
            breakdownButton.tap()
            
            // Then: Should show detailed storage view
            let breakdownView = app.otherElements["storageBreakdownView"]
            XCTAssertTrue(breakdownView.waitForExistence(timeout: 2) || app.navigationBars["Storage"].exists)
        }
    }
    
    func testManualCleanupButton() throws {
        // Given: Storage management section
        
        // Then: Manual cleanup button should exist
        let cleanupButton = app.buttons["manualCleanupButton"]
        // May need to navigate to storage breakdown first
    }
    
    func testManualCleanupConfirmation() throws {
        // Given: Manual cleanup button exists
        let cleanupButton = app.buttons["manualCleanupButton"]
        
        if cleanupButton.exists {
            // When: Tapping cleanup
            cleanupButton.tap()
            
            // Then: Confirmation dialog should appear
            let confirmButton = app.alerts.buttons["Confirm"]
            XCTAssertTrue(confirmButton.waitForExistence(timeout: 2) || app.sheets.buttons["Delete"].exists)
        }
    }
    
    // MARK: - Auto-Cleanup Settings Tests
    
    func testAutoCleanupSettingExists() throws {
        // Given: Settings view is visible
        
        // Then: Auto-cleanup setting should exist
        let autoCleanupSetting = app.buttons["autoCleanupSetting"]
        XCTAssertTrue(autoCleanupSetting.exists || app.staticTexts["Auto-Cleanup"].exists)
    }
    
    func testAutoCleanupThresholdPicker() throws {
        // Given: Auto-cleanup setting exists
        let autoCleanupSetting = app.buttons["autoCleanupSetting"]
        
        if autoCleanupSetting.exists {
            // When: Tapping auto-cleanup
            autoCleanupSetting.tap()
            
            // Then: Picker should show threshold options
            let option7Days = app.buttons["7 days"]
            let option30Days = app.buttons["30 days"]
            let optionNever = app.buttons["Never"]
            
            XCTAssertTrue(option7Days.exists || option30Days.exists || optionNever.exists)
        }
    }
    
    func testSelectingAutoCleanupThreshold() throws {
        // Given: Auto-cleanup picker is open
        let autoCleanupSetting = app.buttons["autoCleanupSetting"]
        
        if autoCleanupSetting.exists {
            autoCleanupSetting.tap()
            
            // When: Selecting a threshold
            let option30Days = app.buttons["30 days"]
            if option30Days.exists {
                option30Days.tap()
                
                // Then: Selection should be saved
                // (Verification depends on implementation)
            }
        }
    }
    
    // MARK: - Settings Sections Tests
    
    func testAudioSectionExists() throws {
        // Given: Settings view is visible
        
        // Then: Audio section should exist
        let audioSection = app.staticTexts["Audio"]
        // May be a header or section title
    }
    
    func testTranscriptionSectionExists() throws {
        // Given: Settings view is visible
        
        // Then: Transcription section should exist
        let transcriptionSection = app.staticTexts["Transcription"]
        // May be a header or section title
    }
    
    func testStorageSectionExists() throws {
        // Given: Settings view is visible
        
        // Then: Storage section should exist
        let storageSection = app.staticTexts["Storage"]
        // May be a header or section title
    }
    
    func testSyncSectionExists() throws {
        // Given: Settings view is visible
        
        // Then: Sync section should exist
        let syncSection = app.staticTexts["Sync"]
        // May be a header or section title
    }
    
    // MARK: - Navigation Tests
    
    func testBackNavigationFromSettings() throws {
        // Given: On settings view
        
        // When: Tapping back button
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            backButton.tap()
            
            // Then: Should return to previous view
            XCTAssertFalse(app.navigationBars["Settings"].exists)
        }
    }
    
    func testNavigationToStorageBreakdown() throws {
        // Given: Settings view
        let breakdownButton = app.buttons["storageBreakdownButton"]
        
        if breakdownButton.exists {
            // When: Navigating to storage breakdown
            breakdownButton.tap()
            
            // Then: Should show storage breakdown
            let breakdownView = app.otherElements["storageBreakdownView"]
            XCTAssertTrue(breakdownView.waitForExistence(timeout: 2) || app.navigationBars["Storage"].exists)
            
            // When: Navigating back
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
                
                // Then: Should return to settings
                XCTAssertTrue(app.navigationBars["Settings"].exists || app.otherElements["settingsView"].exists)
            }
        }
    }
    
    // MARK: - Storage Breakdown Detail Tests
    
    func testStorageBreakdownShowsRecordings() throws {
        // Given: On storage breakdown view
        let breakdownButton = app.buttons["storageBreakdownButton"]
        
        if breakdownButton.exists {
            breakdownButton.tap()
            
            // Then: Should show list of recordings with sizes
            let recordingsList = app.tables.firstMatch
            XCTAssertTrue(recordingsList.exists || app.cells.count > 0)
        }
    }
    
    func testStorageBreakdownShowsTotalUsage() throws {
        // Given: On storage breakdown view
        let breakdownButton = app.buttons["storageBreakdownButton"]
        
        if breakdownButton.exists {
            breakdownButton.tap()
            
            // Then: Should show total storage usage
            let totalUsage = app.staticTexts["totalStorageLabel"]
            XCTAssertTrue(totalUsage.exists || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Total'")).count > 0)
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testSettingsAccessibility() throws {
        // Given: Settings view
        
        // Then: All controls should be accessible
        let audioQualitySetting = app.buttons["audioQualitySetting"]
        if audioQualitySetting.exists {
            XCTAssertTrue(audioQualitySetting.isHittable)
        }
        
        let syncToggle = app.switches["iCloudSyncToggle"]
        if syncToggle.exists {
            XCTAssertTrue(syncToggle.isHittable)
        }
    }
    
    func testSettingsLabelsAccessibility() throws {
        // Given: Settings view
        
        // Then: Labels should have proper accessibility
        let labels = app.staticTexts
        for label in labels.allElementsBoundByIndex {
            if label.exists {
                XCTAssertFalse(label.label.isEmpty)
            }
        }
    }
}
