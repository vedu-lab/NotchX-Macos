import SwiftUI

// MARK: - Floating Volume/Brightness HUD (Pops Below Notch, Reference: media_1790756353869.png)

/// The HUD pill that floats BELOW the physical notch — wide dark capsule with:
/// [speaker/sun icon]  [glowing white progress bar + NX sparkle at thumb]  [94%]
struct SystemHUDView: View {
    @ObservedObject var manager = SystemHUDManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Icon (Volume or Brightness) — left edge
            hudIcon
                .frame(width: 20, height: 20)
            
            // 2. Glowing White Progress Bar with NX Sparkle at Thumb
            SparklingBarView(
                value: manager.isMuted ? 0 : CGFloat(manager.value),
                isIncreasing: manager.isIncreasing,
                sparkleTrigger: manager.sparkleTrigger
            )
            .frame(height: 12)
            
            // 3. Percentage / Mute label — right edge
            Text(manager.isMuted ? "MUTE" : "\(Int(round(manager.value * 100)))%")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(white: 0.06))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
                .shadow(color: Color.black.opacity(0.65), radius: 12, y: 4)
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.88, anchor: .top).combined(with: .opacity),
            removal: .scale(scale: 0.92, anchor: .top).combined(with: .opacity)
        ))
    }
    
    @ViewBuilder
    private var hudIcon: some View {
        switch manager.hudType {
        case .volume:
            if manager.isMuted {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            } else if manager.value > 0.65 {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            } else if manager.value > 0.3 {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            } else if manager.value > 0 {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
        case .brightness:
            if manager.value > 0.65 {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            } else if manager.value > 0.30 {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "sun.dust.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }
}

// MARK: - Glowing White Progress Bar + NX Sparkle at Fill Thumb

struct SparklingBarView: View {
    let value: CGFloat
    let isIncreasing: Bool
    let sparkleTrigger: Int
    
    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let fillW = max(0, min(totalW, totalW * value))
            
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                    )
                
                // Glowing Filled Bar (brilliant white glow just like image)
                if fillW > 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.92)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillW)
                        .shadow(color: Color.white.opacity(0.55), radius: 5, x: 0, y: 0)
                        .shadow(color: Color.white.opacity(0.25), radius: 10, x: 0, y: 0)
                }
                
                // NX Sparkle Icon at Thumb Position (matches reference image)
                if fillW > 10 {
                    SparkleCluster(isIncreasing: isIncreasing, trigger: sparkleTrigger)
                        .offset(x: max(0, fillW - 10), y: -5)
                }
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: value)
    }
}

// MARK: - NX Sparkle / Star Cluster at Progress Thumb

struct SparkleCluster: View {
    let isIncreasing: Bool
    let trigger: Int
    
    var body: some View {
        ZStack {
            // Main glowing star — matches the sparkle in the reference image
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .white, radius: 5)
                .shadow(color: .white.opacity(0.6), radius: 8)
                .scaleEffect(isIncreasing ? 1.28 : 1.0)
                .rotationEffect(.degrees(Double((trigger * 45) % 360)))
            
            // Secondary satellite sparkle
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.80))
                .offset(x: isIncreasing ? 5 : -3, y: -5)
                .scaleEffect(isIncreasing ? 1.1 : 0.85)
            
            // Micro glow dot
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .shadow(color: .white, radius: 3)
                .offset(x: isIncreasing ? 6 : -2, y: 5)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.65), value: trigger)
    }
}
