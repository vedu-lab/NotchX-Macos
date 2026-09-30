// Copyright © 2026 Vedant. All rights reserved.
import SwiftUI
import AppKit

/// Apple cursive "hello." flourish view rendered using native macOS Snell Roundhand font
/// Features:
/// - Exact authentic Apple cursive styling matching modern macOS Hello aesthetic
/// - Liquid glass spectral shimmer gradient animation
/// - Zero distracting language text (pure Apple cursive flourish)
/// - Controllable from Settings
struct HelloScriptView: View {
    @ObservedObject private var greetingManager = GreetingManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    var compact: Bool = false
    
    var body: some View {
        if compact {
            compactFlourish
        } else {
            fullHeroFlourish
        }
    }
    
    // MARK: - Compact Flourish (For Notch Header Row — Visible All The Time)
    
    private var compactFlourish: some View {
        Button(action: {
            greetingManager.replayGreeting()
        }) {
            HStack(spacing: 5) {
                // Apple Cursive Script Word
                Text(greetingManager.currentWord)
                    .font(.custom("Snell Roundhand Bold", size: 17))
                    .foregroundColor(.white)
                    .shadow(color: Color.white.opacity(0.35), radius: 3)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.28),
                                        Color.purple.opacity(0.35),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .help("Apple \"\(greetingManager.currentWord)\" flourish — Click to replay")
    }
    
    // MARK: - Full Hero Flourish (For Launch Pop-up Overlay)
    
    private var fullHeroFlourish: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let shimmerPhase = CGFloat(t.truncatingRemainder(dividingBy: 2.2) / 2.2)
            
            VStack(spacing: 4) {
                ZStack {
                    // Base cursive text
                    Text(greetingManager.currentWord)
                        .font(.custom("Snell Roundhand Bold", size: 40))
                        .foregroundColor(.white.opacity(0.95))
                    
                    // Liquid Glass Spectral Shimmer Overlay
                    Text(greetingManager.currentWord)
                        .font(.custom("Snell Roundhand Bold", size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: max(0, shimmerPhase - 0.25)),
                                    .init(color: .white.opacity(0.90), location: shimmerPhase),
                                    .init(color: .purple.opacity(0.75), location: min(1, shimmerPhase + 0.15)),
                                    .init(color: .clear, location: min(1, shimmerPhase + 0.35))
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blendMode(.plusLighter)
                }
                .shadow(color: Color.purple.opacity(0.45), radius: 10, y: 2)
            }
        }
    }
}
