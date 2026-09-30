import SwiftUI
import AppKit

// MARK: - Glass Card Container

/// Multi-layered frosted glass card matching macOS 27 glass aesthetics
public struct GlassCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let padding: CGFloat
    public let content: Content
    
    public init(cornerRadius: CGFloat = 14, padding: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        ZStack {
            // Layer 1: Hardware-accelerated backdrop blur
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .clipShape(shape)
            
            // Layer 2: Smoked dark acrylic tint with liquid sheen
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.black.opacity(0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Layer 3: Specular gradient border stroke
            shape
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.32), location: 0.0),
                            .init(color: Color.white.opacity(0.12), location: 0.4),
                            .init(color: Color.white.opacity(0.04), location: 0.7),
                            .init(color: Color.white.opacity(0.18), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
            
            // Layer 4: Content
            content
                .padding(padding)
        }
    }
}

// MARK: - Glass Section Header

public struct GlassSectionHeader: View {
    public let title: String
    public let subtitle: String?
    public let icon: String
    public let tint: Color
    
    public init(title: String, subtitle: String? = nil, icon: String, tint: Color) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
                    )
                    .shadow(color: tint.opacity(0.4), radius: 4, y: 1.5)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Live Interactive Glass Preview HUD

/// Interactive real-time live preview of the Notch showing glass transparency, tint, and curvature
public struct GlassPreviewHUD: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan)
                    Text("LIVE GLASS PREVIEW")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.8)
                }
                
                Spacer()
                
                Text("\(Int(settings.notchTransparency * 100))% Glass · \(settings.glassMaterialType.rawValue)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white.opacity(0.55))
            }
            
            // Preview Canvas with background wallpaper sample to showcase glass blur
            ZStack {
                // Background scenic wallpaper simulation
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.28, blue: 0.55),
                        Color(red: 0.35, green: 0.15, blue: 0.45),
                        Color(red: 0.10, green: 0.40, blue: 0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    // Subtle geometric shapes behind glass to prove refraction/blur
                    HStack(spacing: 30) {
                        Circle()
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .blur(radius: 6)
                        Circle()
                            .fill(Color.cyan.opacity(0.6))
                            .frame(width: 70, height: 70)
                            .blur(radius: 8)
                        Circle()
                            .fill(Color.purple.opacity(0.6))
                            .frame(width: 45, height: 45)
                            .blur(radius: 5)
                    }
                )
                
                // Mini Notch Overlay
                let previewTopR = settings.notchTopCornerRadius * 0.55
                let previewBottomR = settings.notchBottomCornerRadius * 0.55
                let previewShape = NotchShape(topCornerRadius: previewTopR, bottomCornerRadius: previewBottomR)
                
                ZStack(alignment: .top) {
                    // Glass material backdrop blur
                    if settings.notchTransparency > 0.02 {
                        VisualEffectView(material: settings.glassMaterialType.nsMaterial, blendingMode: .behindWindow)
                            .clipShape(previewShape)
                    }
                    
                    // Dark base layer
                    Color.black.opacity(max(1.0 - settings.notchTransparency, 0.15))
                        .clipShape(previewShape)
                    
                    // Glass Tint layer
                    if settings.notchTransparency > 0.05 && settings.glassTintType != .obsidian {
                        settings.glassTintType.color.opacity(settings.notchTransparency * 0.45)
                            .clipShape(previewShape)
                    }
                    
                    // Specular Rim
                    if settings.glassBorderGlow {
                        previewShape
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.20 + 0.35 * settings.glassSheenIntensity),
                                        settings.glassTintType.color.opacity(0.35),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.0
                            )
                    }
                    
                    // Mini content inside preview
                    HStack(spacing: 8) {
                        NXLogoView(height: 10)
                            .opacity(0.9)
                        
                        Text("NotchX Glass HUD")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
                .frame(width: 260, height: 50, alignment: .top)
                .offset(y: -4)
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.6)
                )
        )
    }
}
