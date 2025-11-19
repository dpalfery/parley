//
//  UserFeedbackExamples.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//
//  This file contains examples of how to use the error handling and user feedback utilities.
//  These examples are for documentation purposes and demonstrate best practices.
//

import SwiftUI

// MARK: - Error Alert Examples

/*
 Example 1: Using errorAlert modifier
 
 struct MyView: View {
     @State private var error: Error?
     
     var body: some View {
         VStack {
             Button("Do Something") {
                 do {
                     try riskyOperation()
                 } catch {
                     self.error = error
                     ErrorLogger.log(error, context: "MyView.riskyOperation")
                 }
             }
         }
         .errorAlert($error)
     }
 }
 */

// MARK: - Toast Notification Examples

/*
 Example 2: Using toast notifications
 
 struct MyView: View {
     @StateObject private var toastManager = ToastManager()
     
     var body: some View {
         VStack {
             Button("Save Recording") {
                 Task {
                     do {
                         try await saveRecording()
                         toastManager.success("Recording saved successfully")
                         HapticFeedback.save()
                     } catch {
                         toastManager.error("Failed to save recording")
                         HapticFeedback.error()
                         ErrorLogger.log(error, context: "MyView.saveRecording")
                     }
                 }
             }
         }
         .toast(toastManager)
     }
 }
 */

// MARK: - Loading Indicator Examples

/*
 Example 3: Using loading overlay
 
 struct MyView: View {
     @State private var isLoading = false
     
     var body: some View {
         VStack {
             Button("Load Data") {
                 Task {
                     isLoading = true
                     defer { isLoading = false }
                     
                     await loadData()
                 }
             }
         }
         .loading(isLoading, message: "Loading recordings...")
     }
 }
 */

// MARK: - Progress View Examples

/*
 Example 4: Using progress overlay for long-running tasks
 
 struct MyView: View {
     @State private var isExporting = false
     @State private var exportProgress: Double = 0.0
     
     var body: some View {
         VStack {
             Button("Export Recording") {
                 Task {
                     isExporting = true
                     defer { isExporting = false }
                     
                     for i in 0...10 {
                         exportProgress = Double(i) / 10.0
                         try? await Task.sleep(nanoseconds: 500_000_000)
                     }
                     
                     toastManager.success("Export completed")
                     HapticFeedback.success()
                 }
             }
         }
         .progressOverlay(
             isShowing: isExporting,
             title: "Exporting",
             progress: exportProgress,
             message: "Preparing your recording..."
         )
     }
 }
 */

// MARK: - Haptic Feedback Examples

/*
 Example 5: Using haptic feedback for key interactions
 
 struct RecordButton: View {
     @Binding var isRecording: Bool
     
     var body: some View {
         Button(action: {
             isRecording.toggle()
             
             if isRecording {
                 HapticFeedback.recordingStart()
             } else {
                 HapticFeedback.recordingStop()
             }
         }) {
             Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                 .font(.system(size: 64))
         }
     }
 }
 */

// MARK: - Combined Example

/*
 Example 6: Combining multiple feedback mechanisms
 
 struct RecordingView: View {
     @StateObject private var viewModel = RecordingViewModel()
     @StateObject private var toastManager = ToastManager()
     @State private var error: Error?
     
     var body: some View {
         VStack {
             Button("Start Recording") {
                 Task {
                     do {
                         HapticFeedback.recordingStart()
                         try await viewModel.startRecording()
                         toastManager.success("Recording started")
                     } catch {
                         self.error = error
                         HapticFeedback.error()
                         ErrorLogger.log(error, context: "RecordingView.startRecording")
                     }
                 }
             }
             
             Button("Stop Recording") {
                 Task {
                     do {
                         HapticFeedback.recordingStop()
                         try await viewModel.stopRecording()
                         toastManager.success("Recording saved")
                     } catch {
                         self.error = error
                         HapticFeedback.error()
                         ErrorLogger.log(error, context: "RecordingView.stopRecording")
                     }
                 }
             }
         }
         .loading(viewModel.isProcessing, message: "Processing recording...")
         .errorAlert($error)
         .toast(toastManager)
     }
 }
 */

// MARK: - Error Logging Examples

/*
 Example 7: Using ErrorLogger for consistent error logging
 
 func performOperation() {
     do {
         try riskyOperation()
     } catch let error as RecordingError {
         ErrorLogger.log(error, context: "performOperation")
         // Handle recording-specific error
     } catch let error as StorageError {
         ErrorLogger.log(error, context: "performOperation")
         // Handle storage-specific error
     } catch {
         ErrorLogger.log(error, context: "performOperation")
         // Handle generic error
     }
 }
 */

// MARK: - Recording Permission Example

struct RecordingPermissionExampleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var viewModel = RecordingViewModel(
        recordingService: RecordingService(),
        transcriptionService: TranscriptionService(),
        permissionManager: PermissionManager()
    )
    
    var body: some View {
        VStack {
            Text("Recording Permission Example")
                .font(.title)
            
            Button("Request Microphone Permission") {
                Task {
                    _ = await permissionManager.requestMicrophonePermission()
                }
            }
        }
        .padding()
        .onReceive(permissionManager.$microphonePermissionStatus) { newValue in
            if newValue == .granted {
                // Permission granted, proceed with recording
                HapticFeedback.success()
            } else {
                // Permission denied, show error
                HapticFeedback.error()
            }
        }
    }
}
