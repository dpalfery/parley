//
//  Colors.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

/// Semantic colors that adapt to light and dark modes
extension Color {
    
    // MARK: - Recording State Colors
    
    /// Color for recording state indicator
    static let recordingActive = Color.red
    
    /// Color for paused state indicator
    static let recordingPaused = Color.orange
    
    /// Color for processing state indicator
    static let recordingProcessing = Color.blue
    
    /// Color for idle/ready state indicator
    static let recordingIdle = Color.gray
    
    // MARK: - Audio Level Colors
    
    /// Color for normal audio levels (0-60%)
    static let audioLevelNormal = Color.green
    
    /// Color for elevated audio levels (60-85%)
    static let audioLevelElevated = Color.yellow
    
    /// Color for high/clipping audio levels (85-100%)
    static let audioLevelHigh = Color.red
    
    /// Color for inactive audio level bars
    static var audioLevelInactive: Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.systemGray5
                : UIColor.systemGray4
        })
    }
    
    // MARK: - UI Element Colors
    
    /// Primary accent color for interactive elements
    static let appAccent = Color.blue
    
    /// Color for speaker labels
    static let speakerLabel = Color.blue
    
    /// Color for low confidence indicators
    static let lowConfidence = Color.orange
    
    /// Color for sync status - synced
    static let syncedStatus = Color.green
    
    /// Color for sync status - not synced
    static let notSyncedStatus = Color.orange
    
    // MARK: - Background Colors
    
    /// Background color for cards and elevated surfaces
    static var cardBackground: Color {
        Color(uiColor: .systemBackground)
    }
    
    /// Background color for secondary surfaces
    static var secondaryBackground: Color {
        Color(uiColor: .secondarySystemBackground)
    }
    
    /// Background color for grouped content
    static var groupedBackground: Color {
        Color(uiColor: .systemGroupedBackground)
    }
    
    /// Background color for input fields and text areas
    static var inputBackground: Color {
        Color(uiColor: .systemGray6)
    }
    
    // MARK: - Text Colors
    
    /// Primary text color
    static var primaryText: Color {
        Color(uiColor: .label)
    }
    
    /// Secondary text color for less prominent information
    static var secondaryText: Color {
        Color(uiColor: .secondaryLabel)
    }
    
    /// Tertiary text color for disabled or placeholder text
    static var tertiaryText: Color {
        Color(uiColor: .tertiaryLabel)
    }
    
    // MARK: - Tag Colors
    
    /// Background color for tags
    static var tagBackground: Color {
        Color.blue.opacity(0.15)
    }
    
    /// Text color for tags
    static let tagText = Color.blue
    
    // MARK: - Highlight Colors
    
    /// Background color for highlighted transcript segments
    static var transcriptHighlight: Color {
        Color.blue.opacity(0.1)
    }
    
    /// Shadow color for cards
    static var cardShadow: Color {
        Color.black.opacity(0.05)
    }
    
    // MARK: - Filter Chip Colors
    
    /// Background color for filter chips
    static var filterChipBackground: Color {
        Color.blue.opacity(0.2)
    }
    
    /// Text color for filter chips
    static let filterChipText = Color.blue
}

/// Extension for UIColor to support dynamic colors
extension UIColor {
    
    /// Creates a dynamic color that adapts to light and dark modes
    /// - Parameters:
    ///   - light: Color for light mode
    ///   - dark: Color for dark mode
    /// - Returns: A dynamic UIColor
    static func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }
}
