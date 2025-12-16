//
//  AudioLevelMeterView.swift
//  Parley
//
//  Created on 2025-11-16.
//

import SwiftUI

/// Animated audio level meter with color-coded bars
struct AudioLevelMeterView: View {
    let audioLevel: Float
    
    private let barCount = 20
    private let barSpacing: CGFloat = 4
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    AudioBar(
                        isActive: Float(index) < audioLevel * Float(barCount),
                        height: geometry.size.height,
                        color: barColor(for: index)
                    )
                }
            }
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        
        if threshold < 0.6 {
            return .audioLevelNormal
        } else if threshold < 0.85 {
            return .audioLevelElevated
        } else {
            return .audioLevelHigh
        }
    }
}

/// Individual animated bar in the audio level meter
struct AudioBar: View {
    let isActive: Bool
    let height: CGFloat
    let color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isActive ? color : Color.audioLevelInactive)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .animation(.easeInOut(duration: 0.1), value: isActive)
    }
}

#Preview {
    VStack(spacing: 20) {
        AudioLevelMeterView(audioLevel: 0.3)
            .frame(height: 100)
            .padding()
        
        AudioLevelMeterView(audioLevel: 0.7)
            .frame(height: 100)
            .padding()
        
        AudioLevelMeterView(audioLevel: 0.95)
            .frame(height: 100)
            .padding()
    }
}
