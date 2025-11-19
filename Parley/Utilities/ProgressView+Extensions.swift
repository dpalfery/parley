//
//  ProgressView+Extensions.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

/// A custom progress view for long-running tasks
struct TaskProgressView: View {
    let title: String
    let progress: Double
    let message: String?
    
    init(title: String, progress: Double, message: String? = nil) {
        self.title = title
        self.progress = progress
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
            
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

/// View modifier to show a progress overlay
struct ProgressOverlayModifier: ViewModifier {
    let isShowing: Bool
    let title: String
    let progress: Double
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isShowing)
            
            if isShowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                TaskProgressView(title: title, progress: progress, message: message)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isShowing)
    }
}

/// Extension to make progress overlay easy to use
extension View {
    /// Adds a progress overlay to a view
    /// - Parameters:
    ///   - isShowing: Whether to show the progress indicator
    ///   - title: The title of the task
    ///   - progress: The progress value (0.0 to 1.0)
    ///   - message: Optional message to display
    /// - Returns: A view with a progress overlay
    func progressOverlay(
        isShowing: Bool,
        title: String,
        progress: Double,
        message: String? = nil
    ) -> some View {
        modifier(ProgressOverlayModifier(
            isShowing: isShowing,
            title: title,
            progress: progress,
            message: message
        ))
    }
}
