//
//  LoadingView.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

/// A loading indicator view with optional message
struct LoadingView: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle())
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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

/// View modifier to show a loading overlay
struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
            
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                LoadingView(message: message)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

/// Extension to make loading overlay easy to use
extension View {
    /// Adds a loading overlay to a view
    /// - Parameters:
    ///   - isLoading: Whether to show the loading indicator
    ///   - message: Optional message to display with the loading indicator
    /// - Returns: A view with a loading overlay
    func loading(_ isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}
