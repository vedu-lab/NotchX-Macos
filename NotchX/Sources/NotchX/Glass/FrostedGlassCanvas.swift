import SwiftUI
import AppKit

/// Renders a multi-layered luxury frosted glass surface mimicking real Apple Liquid Retina XDR / Pro Display glass:
/// 1. True system-integrated backdrop blur via NSVisualEffectView
/// 2. Specular glass rim bevel catching ambient light along curved contours
/// 3. Deep ambient occlusion shadow casting realistic real-time shadows on background windows
public struct FrostedGlassCanvas<S: Shape>: View {
    public let shape: S
    public let transparency: Double
    public let hasShadow: Bool
    
    public init(shape: S, transparency: Double = 0.15, hasShadow: Bool = true) {
        self.shape = shape
        self.transparency = transparency
        self.hasShadow = hasShadow
    }
    
    public var body: some View {
        ZStack {
            // Layer 1: Ambient Occlusion Real-Time Shadows (casted onto windows behind)
            if hasShadow {
                // Wide ambient penumbra
                shape
                    .fill(Color.black.opacity(0.38))
                    .blur(radius: 28)
                    .offset(y: 14)
                
                // Tight contact shadow
                shape
                    .fill(Color.black.opacity(0.46))
                    .blur(radius: 8)
                    .offset(y: 3)
            }
            
            // Layer 2: Native Hardware Backdrop Blur (.hudWindow behind window)
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(shape)
                .opacity(max(transparency * 1.5, 0.4))
            
            // Layer 3: Smoked Obsidian Dark Glass Tint
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(max(1.0 - transparency, 0.65)),
                            Color(red: 0.05, green: 0.05, blue: 0.07).opacity(max(1.0 - transparency, 0.75))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Layer 4: Specular Glass Bevel Rim (Curved highlight along upper perimeter)
            shape
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.35), location: 0.0),
                            .init(color: Color.white.opacity(0.12), location: 0.3),
                            .init(color: Color.white.opacity(0.04), location: 0.7),
                            .init(color: Color.white.opacity(0.20), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
            
            // Layer 5: Inner Refractive Micro-Glow
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 0.5
                )
        }
    }
}
