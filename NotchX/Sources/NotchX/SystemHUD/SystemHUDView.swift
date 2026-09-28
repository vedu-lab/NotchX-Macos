import SwiftUI

/// Black & White Sparkling System HUD for Volume and Brightness changes
struct SystemHUDView: View {
    @ObservedObject var manager = SystemHUDManager.shared
    
    var body: some View {
        HStack(spacing: 11) {
            // 1. Icon (Volume or Brightness)
            hudIcon
                .frame(width: 18)
            
            // 2. Black & White Sparkling Bar
            SparklingBarView(
                value: manager.isMuted ? 0 : CGFloat(manager.value),
                isIncreasing: manager.isIncreasing,
                sparkleTrigger: manager.sparkleTrigger
            )
            .frame(width: 130, height: 10)
            
            // 3. Percentage / Mute Label
            Text(manager.isMuted ? "MUTE" : "\(Int(round(manager.value * 100)))%")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.black)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: Color.black.opacity(0.7), radius: 8, y: 2)
        )
    }
    
    @ViewBuilder
    private var hudIcon: some View {
        switch manager.hudType {
        case .volume:
            if manager.isMuted {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
            } else if manager.value > 0.65 {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            } else if manager.value > 0.3 {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            } else if manager.value > 0 {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        case .brightness:
            Image(systemName: "sun.max.fill")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

/// Black & White progress bar with dynamic sparkling particle animation on increase / decrease
struct SparklingBarView: View {
    let value: CGFloat
    let isIncreasing: Bool
    let sparkleTrigger: Int
    
    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let fillW = max(0, min(totalW, totalW * value))
            
            ZStack(alignment: .leading) {
                // Background Track (Deep pitch black / subtle white border)
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.20), lineWidth: 0.6)
                    )
                
                // Active Filled Bar (Pure brilliant white)
                Capsule()
                    .fill(Color.white)
                    .frame(width: fillW)
                    .shadow(color: Color.white.opacity(0.4), radius: 3, x: 0, y: 0)
                
                // Sparkling Head Particles
                if fillW > 6 {
                    SparkleCluster(
                        isIncreasing: isIncreasing,
                        trigger: sparkleTrigger
                    )
                    .offset(x: fillW - 8, y: -4)
                }
            }
        }
        .animation(.spring(response: 0.20, dampingFraction: 0.72), value: value)
    }
}

/// Dynamic white sparkle cluster that animates whenever volume or brightness changes
struct SparkleCluster: View {
    let isIncreasing: Bool
    let trigger: Int
    
    var body: some View {
        ZStack {
            // Main glowing star sparkle
            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .white, radius: 4)
                .scaleEffect(isIncreasing ? 1.25 : 1.0)
                .rotationEffect(.degrees(Double((trigger * 45) % 360)))
            
            // Secondary satellite star
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .offset(x: isIncreasing ? 4 : -3, y: -5)
                .scaleEffect(isIncreasing ? 1.15 : 0.9)
            
            // Micro glimmer dot
            Circle()
                .fill(Color.white)
                .frame(width: 2.5, height: 2.5)
                .shadow(color: .white, radius: 2)
                .offset(x: isIncreasing ? 6 : -2, y: 4)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.65), value: trigger)
    }
}
