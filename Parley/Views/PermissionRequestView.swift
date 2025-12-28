//
//  PermissionRequestView.swift
//  Parley
//
//  Created on 2025-11-16.
//

import SwiftUI

/// View for requesting permissions on first launch
struct PermissionRequestView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var isRequestingPermissions = false
    @Binding var isPresented: Bool
    
    private var permissionManager: PermissionManager {
        appEnvironment.permissionManager
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.appAccent)
                
                Text("Welcome to Parley")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("To record and transcribe meetings, we need access to your microphone and speech recognition.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Permission items
            VStack(alignment: .leading, spacing: 20) {
                PermissionItemView(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required to record audio during meetings"
                )
                
                PermissionItemView(
                    icon: "text.bubble.fill",
                    title: "Speech Recognition",
                    description: "Required to transcribe audio to text in real-time"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Action button
            Button(action: {
                requestPermissions()
            }) {
                if isRequestingPermissions {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(Color.appAccent)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(isRequestingPermissions)
        }
        .padding(.vertical, 40)
        // Note: Permission alert functionality temporarily disabled for compilation
    }
    
    private func requestPermissions() {
        isRequestingPermissions = true
        
        Task {
            let granted = await appEnvironment.permissionManager.requestRecordingPermissions()
            
            await MainActor.run {
                isRequestingPermissions = false
                if granted {
                    isPresented = false
                }
            }
        }
    }
}

/// Individual permission item view
struct PermissionItemView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.appAccent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    PermissionRequestView(isPresented: .constant(true))
        .environmentObject(AppEnvironment.preview())
}
