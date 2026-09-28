import SwiftUI
import AppKit

/// Observable hover state avoiding broken @State macro
public class MicVeilHoverState: ObservableObject {
    public static let shared = MicVeilHoverState()
    @Published public var isHovered: Bool = false
}

/// Visual Hardware-Styled Microphone Privacy Veil
/// - Active (Amber LED): Blinks subtly to signal that microphone input stream is live
/// - Killed (Red Shield): Shows prominent hardware lockout indicating 0% input volume & hardware isolation
/// - One-Click Action: Clicking engages/disengages the Global Kill Switch with physical haptic click
public struct MicrophoneVeilView: View {
    @ObservedObject private var veilManager = MicrophoneVeilManager.shared
    @ObservedObject private var hover = MicVeilHoverState.shared
    
    public var compact: Bool = false
    
    public init(compact: Bool = false) {
        self.compact = compact
    }
    
    public var body: some View {
        Button(action: {
            veilManager.toggleKillSwitch()
        }) {
            if compact {
                // Discrete LED pill for collapsed notch
                HStack(spacing: 4) {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6.5, height: 6.5)
                        .shadow(color: indicatorColor.opacity(0.8), radius: 3)
                    
                    if veilManager.isKillSwitchActive {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
            } else {
                // Full luxury hardware privacy badge for expanded notch
                HStack(spacing: 6) {
                    // Pulsing Hardware LED
                    ZStack {
                        Circle()
                            .fill(indicatorColor.opacity(0.25))
                            .frame(width: 14, height: 14)
                        
                        Circle()
                            .fill(indicatorColor)
                            .frame(width: 7, height: 7)
                            .shadow(color: indicatorColor.opacity(0.9), radius: 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(veilManager.isKillSwitchActive ? "MIC MUTED (0%)" : (veilManager.isMicStreaming ? "MIC LIVE" : "MIC SECURE"))
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .foregroundColor(veilManager.isKillSwitchActive ? .red : (veilManager.isMicStreaming ? .orange : .white.opacity(0.7)))
                            .tracking(0.5)
                        
                        Text(veilManager.isKillSwitchActive ? "Kill Switch Active" : "Click to Kill Mic")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Image(systemName: veilManager.isKillSwitchActive ? "shield.slash.fill" : "shield.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(veilManager.isKillSwitchActive ? .red : .white.opacity(0.6))
                        .padding(.leading, 2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            veilManager.isKillSwitchActive
                                ? Color.red.opacity(0.18)
                                : (hover.isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            veilManager.isKillSwitchActive ? Color.red.opacity(0.6) : Color.white.opacity(0.12),
                            lineWidth: 0.5
                        )
                )
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hover.isHovered = isHovering
        }
        .help(veilManager.isKillSwitchActive ? "Microphone hardware silenced at 0%. Click to restore." : "Click to mechanically kill microphone hardware input.")
    }
    
    private var indicatorColor: Color {
        if veilManager.isKillSwitchActive {
            return .red
        } else if veilManager.isMicStreaming {
            return .orange
        } else {
            return .green.opacity(0.7)
        }
    }
}
