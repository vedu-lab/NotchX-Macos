// Copyright © 2026 Vedant. All rights reserved.
import SwiftUI
import AppKit

/// Floating Apple "hello." greeting pill that hovers below the notch on launch
/// Matches the exact floating dock bar styling and corner curves
struct LaunchGreetingOverlay: View {
    @ObservedObject private var greetingManager = GreetingManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        if greetingManager.isGreetingActive {
            HStack(spacing: 12) {
                // Leading Apple icon
                Image(systemName: "apple.logo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.leading, 4)
                
                // Center: Apple Cursive Hello Shimmer
                HelloScriptView(compact: false)
                    .padding(.vertical, 4)
                
                // Trailing Close Button
                Button(action: {
                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                    greetingManager.dismissGreeting()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.50))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Dismiss Greeting")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.76))
                    .overlay(
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            .clipShape(Capsule())
                            .opacity(0.45)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.32),
                                        Color.purple.opacity(0.35),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.85
                            )
                    )
                    .shadow(color: Color.black.opacity(0.60), radius: 14, y: 6)
            )
            .contentShape(Capsule())
            .onTapGesture {
                greetingManager.replayGreeting()
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.85, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -12)),
                removal: .scale(scale: 0.90, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -10))
            ))
        }
    }
}
