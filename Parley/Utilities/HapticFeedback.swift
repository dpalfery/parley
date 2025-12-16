//
//  HapticFeedback.swift
//  Parley
//
//  Created on 2025-11-16.
//

import UIKit

/// Utility for providing haptic feedback
struct HapticFeedback {
    
    /// Provides haptic feedback for successful operations
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Provides haptic feedback for warnings
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Provides haptic feedback for errors
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Provides light impact haptic feedback
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Provides medium impact haptic feedback
    static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Provides heavy impact haptic feedback
    static func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Provides selection changed haptic feedback
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    /// Provides haptic feedback for recording start
    static func recordingStart() {
        heavyImpact()
    }
    
    /// Provides haptic feedback for recording stop
    static func recordingStop() {
        mediumImpact()
    }
    
    /// Provides haptic feedback for recording pause
    static func recordingPause() {
        lightImpact()
    }
    
    /// Provides haptic feedback for recording resume
    static func recordingResume() {
        lightImpact()
    }
    
    /// Provides haptic feedback for button tap
    static func buttonTap() {
        lightImpact()
    }
    
    /// Provides haptic feedback for deletion
    static func delete() {
        warning()
    }
    
    /// Provides haptic feedback for save operation
    static func save() {
        success()
    }
}
