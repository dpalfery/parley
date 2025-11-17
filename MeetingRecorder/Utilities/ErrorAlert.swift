//
//  ErrorAlert.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

/// A view modifier that presents errors in a consistent alert dialog
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: Error?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(error != nil), presenting: error) { _ in
                Button("OK") {
                    error = nil
                }
            } message: { error in
                Text(error.localizedDescription)
            }
    }
}

/// Extension to make error alert modifier easy to use
extension View {
    /// Presents an alert when an error occurs
    /// - Parameter error: A binding to an optional Error
    /// - Returns: A view that presents an alert when the error is non-nil
    func errorAlert(_ error: Binding<Error?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}
