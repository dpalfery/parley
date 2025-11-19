//
//  ContentView.swift
//  MeetingRecorder
//
//  Created on 2025-11-16.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appEnvironment = AppEnvironment.shared
    
    var body: some View {
        MainTabView()
            .environmentObject(appEnvironment)
    }
}

#Preview {
    ContentView()
}
