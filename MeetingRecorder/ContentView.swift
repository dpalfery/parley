//
//  ContentView.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RecordingListView(storageManager: StorageManager())
    }
}

#Preview {
    ContentView()
}
