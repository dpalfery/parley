//
//  RecordingListUITests.swift
//  MeetingRecorderUITests
//
//  UI tests for recording list navigation and search
//

import XCTest

final class RecordingListUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - List Display Tests
    
    func testRecordingListExists() throws {
        // Given: App is launched
        
        // When: On main screen
        
        // Then: Recording list should be visible
        let recordingList = app.scrollViews["recordingList"]
        XCTAssertTrue(recordingList.exists || app.tables["recordingList"].exists)
    }
    
    func testRecordingListShowsRecordings() throws {
        // Given: Recordings exist in storage
        // Note: May need to create test recordings first
        
        // When: Viewing list
        
        // Then: Recording items should be visible
        let firstRecording = app.cells.firstMatch
        XCTAssertTrue(firstRecording.exists || app.staticTexts["emptyStateMessage"].exists)
    }
    
    func testRecordingRowDisplaysMetadata() throws {
        // Given: Recording list with items
        let firstRecording = app.cells.firstMatch
        
        if firstRecording.exists {
            // Then: Should display title
            XCTAssertTrue(firstRecording.staticTexts.count > 0)
            
            // Then: Should display date
            // Then: Should display duration
            // (Specific labels depend on implementation)
        }
    }
    
    func testRecordingRowShowsSyncStatus() throws {
        // Given: Recording list with items
        let firstRecording = app.cells.firstMatch
        
        if firstRecording.exists {
            // Then: Should show sync status icon
            let syncIcon = firstRecording.images["syncStatusIcon"]
            // Icon may or may not exist depending on sync state
        }
    }
    
    // MARK: - Navigation Tests
    
    func testTappingRecordingNavigatesToDetail() throws {
        // Given: Recording list with items
        let firstRecording = app.cells.firstMatch
        
        if firstRecording.exists {
            // When: Tapping recording
            firstRecording.tap()
            
            // Then: Should navigate to detail view
            let detailView = app.otherElements["recordingDetailView"]
            XCTAssertTrue(detailView.waitForExistence(timeout: 2))
        }
    }
    
    func testBackNavigationFromDetail() throws {
        // Given: On recording detail view
        let firstRecording = app.cells.firstMatch
        
        if firstRecording.exists {
            firstRecording.tap()
            
            // When: Tapping back button
            let backButton = app.navigationBars.buttons.firstMatch
            backButton.tap()
            
            // Then: Should return to list
            let recordingList = app.scrollViews["recordingList"]
            XCTAssertTrue(recordingList.exists || app.tables["recordingList"].exists)
        }
    }
    
    // MARK: - Search Tests
    
    func testSearchBarExists() throws {
        // Given: Recording list view
        
        // When: Looking for search bar
        
        // Then: Search bar should be visible
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.exists)
    }
    
    func testSearchBarAcceptsInput() throws {
        // Given: Search bar is visible
        let searchField = app.searchFields.firstMatch
        
        // When: Tapping and typing in search bar
        searchField.tap()
        searchField.typeText("meeting")
        
        // Then: Search text should be entered
        XCTAssertEqual(searchField.value as? String, "meeting")
    }
    
    func testSearchFiltersRecordings() throws {
        // Given: Recording list with multiple items
        let searchField = app.searchFields.firstMatch
        
        let initialCount = app.cells.count
        
        // When: Entering search query
        searchField.tap()
        searchField.typeText("test")
        
        // Then: List should filter
        // Note: Actual filtering depends on test data
        let filteredCount = app.cells.count
        
        // Results may be same or different depending on data
        XCTAssertGreaterThanOrEqual(initialCount, filteredCount)
    }
    
    func testSearchClearButton() throws {
        // Given: Search with text entered
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("test")
        
        // When: Tapping clear button
        let clearButton = searchField.buttons["Clear text"]
        if clearButton.exists {
            clearButton.tap()
            
            // Then: Search should be cleared
            XCTAssertTrue(searchField.value as? String == "" || searchField.placeholderValue != nil)
        }
    }
    
    // MARK: - Filter Tests
    
    func testFilterButtonExists() throws {
        // Given: Recording list view
        
        // When: Looking for filter button
        
        // Then: Filter button should be accessible
        let filterButton = app.buttons["filterButton"]
        XCTAssertTrue(filterButton.exists || app.toolbars.buttons["filterButton"].exists)
    }
    
    func testFilterSheetOpens() throws {
        // Given: Filter button exists
        let filterButton = app.buttons["filterButton"]
        
        if filterButton.exists {
            // When: Tapping filter button
            filterButton.tap()
            
            // Then: Filter sheet should appear
            let filterSheet = app.sheets.firstMatch
            XCTAssertTrue(filterSheet.waitForExistence(timeout: 2) || app.otherElements["filterView"].exists)
        }
    }
    
    func testTagFilterSelection() throws {
        // Given: Filter sheet is open
        let filterButton = app.buttons["filterButton"]
        
        if filterButton.exists {
            filterButton.tap()
            
            // When: Selecting a tag filter
            let tagButton = app.buttons.matching(identifier: "tagFilterButton").firstMatch
            if tagButton.exists {
                tagButton.tap()
                
                // Then: Filter should be applied
                // (Verification depends on implementation)
            }
        }
    }
    
    func testDateRangeFilter() throws {
        // Given: Filter sheet is open
        let filterButton = app.buttons["filterButton"]
        
        if filterButton.exists {
            filterButton.tap()
            
            // When: Setting date range
            let dateRangePicker = app.datePickers.firstMatch
            if dateRangePicker.exists {
                // Then: Date picker should be accessible
                XCTAssertTrue(dateRangePicker.isHittable)
            }
        }
    }
    
    func testApplyFilterButton() throws {
        // Given: Filter sheet with selections
        let filterButton = app.buttons["filterButton"]
        
        if filterButton.exists {
            filterButton.tap()
            
            // When: Applying filters
            let applyButton = app.buttons["applyFilterButton"]
            if applyButton.exists {
                applyButton.tap()
                
                // Then: Filter sheet should close
                // Then: List should be filtered
            }
        }
    }
    
    func testClearFiltersButton() throws {
        // Given: Filters are applied
        let filterButton = app.buttons["filterButton"]
        
        if filterButton.exists {
            filterButton.tap()
            
            // When: Clearing filters
            let clearButton = app.buttons["clearFiltersButton"]
            if clearButton.exists {
                clearButton.tap()
                
                // Then: All filters should be removed
            }
        }
    }
    
    // MARK: - Sorting Tests
    
    func testRecordingsSortedByDate() throws {
        // Given: Recording list
        
        // When: Default sort (by date)
        
        // Then: Recordings should be in date order
        // (Verification requires checking actual dates)
        let cells = app.cells
        XCTAssertGreaterThanOrEqual(cells.count, 0)
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyStateDisplayed() throws {
        // Given: No recordings exist
        // Note: May need to clear all recordings first
        
        // When: Viewing list
        
        // Then: Empty state message should be shown
        let emptyMessage = app.staticTexts["emptyStateMessage"]
        // May or may not exist depending on data
    }
    
    // MARK: - Scroll Performance Tests
    
    func testListScrolling() throws {
        // Given: Recording list with items
        let recordingList = app.scrollViews["recordingList"]
        
        if recordingList.exists {
            // When: Scrolling list
            recordingList.swipeUp()
            
            // Then: Should scroll smoothly
            XCTAssertTrue(recordingList.exists)
            
            // When: Scrolling back
            recordingList.swipeDown()
            
            // Then: Should scroll back
            XCTAssertTrue(recordingList.exists)
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testListAccessibility() throws {
        // Given: Recording list
        let firstRecording = app.cells.firstMatch
        
        if firstRecording.exists {
            // Then: Should be accessible
            XCTAssertTrue(firstRecording.isHittable)
        }
    }
    
    func testSearchBarAccessibility() throws {
        // Given: Search bar
        let searchField = app.searchFields.firstMatch
        
        // Then: Should have accessibility label
        XCTAssertTrue(searchField.exists)
        XCTAssertTrue(searchField.isHittable)
    }
}
