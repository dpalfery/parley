//
//  ToastView.swift
//  Parley
//
//  Created on 2025-11-16.
//

import SwiftUI

/// A toast notification view that appears temporarily at the bottom of the screen
struct ToastView: View {
    let message: String
    let type: ToastType
    
    enum ToastType {
        case success
        case info
        case warning
        case error
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .success: return .green
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .font(.system(size: 20))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

/// Toast manager to handle displaying toasts
class ToastManager: ObservableObject {
    @Published var toast: Toast?
    
    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let type: ToastView.ToastType
        let duration: TimeInterval
    }
    
    /// Shows a toast notification
    /// - Parameters:
    ///   - message: The message to display
    ///   - type: The type of toast (success, info, warning, error)
    ///   - duration: How long to display the toast (default: 3 seconds)
    func show(_ message: String, type: ToastView.ToastType = .info, duration: TimeInterval = 3.0) {
        toast = Toast(message: message, type: type, duration: duration)
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            if self?.toast?.id == self?.toast?.id {
                self?.toast = nil
            }
        }
    }
    
    /// Shows a success toast
    func success(_ message: String) {
        show(message, type: .success)
    }
    
    /// Shows an info toast
    func info(_ message: String) {
        show(message, type: .info)
    }
    
    /// Shows a warning toast
    func warning(_ message: String) {
        show(message, type: .warning)
    }
    
    /// Shows an error toast
    func error(_ message: String) {
        show(message, type: .error)
    }
}

/// View modifier to display toasts
struct ToastModifier: ViewModifier {
    @ObservedObject var toastManager: ToastManager
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let toast = toastManager.toast {
                VStack {
                    Spacer()
                    
                    ToastView(message: toast.message, type: toast.type)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(), value: toastManager.toast?.id)
                        .padding(.bottom, 20)
                }
                .zIndex(999)
            }
        }
    }
}

/// Extension to make toast modifier easy to use
extension View {
    /// Adds toast notification support to a view
    /// - Parameter toastManager: The toast manager to observe
    /// - Returns: A view that can display toast notifications
    func toast(_ toastManager: ToastManager) -> some View {
        modifier(ToastModifier(toastManager: toastManager))
    }
}
