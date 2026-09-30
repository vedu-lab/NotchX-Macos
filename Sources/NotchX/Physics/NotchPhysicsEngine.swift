import Foundation
import AppKit
import SwiftUI
import Combine

/// Real-time fluid-dynamic spring physics engine for NotchX.
/// Simulates mass-spring-damper oscillator with volumetric conservation (jelly effect)
/// and impact ripples when files or windows are dropped onto the notch.
public class NotchPhysicsEngine: ObservableObject {
    public static let shared = NotchPhysicsEngine()
    
    /// Vertical deformation offset (stretching & compression)
    @Published public var jellyY: CGFloat = 0.0
    
    /// Horizontal volumetric bulge offset (inversely coupled to vertical deform)
    @Published public var jellyX: CGFloat = 0.0
    
    /// Fluid ripple impact intensity (0.0 to 1.0)
    @Published public var rippleIntensity: CGFloat = 0.0
    
    private var displayTimer: Timer?
    private var time: Double = 0.0
    private var amplitude: Double = 0.0
    private let damping: Double = 6.2  // Exponential decay constant
    private let frequency: Double = 22.0 // Oscillation frequency (rad/s)
    
    private init() {}
    
    /// Trigger an organic fluid jelly drop impulse (e.g. when dropping a file into tray)
    public func triggerDropImpact(force: Double = 24.0) {
        DispatchQueue.main.async {
            self.amplitude = force
            self.time = 0.0
            self.rippleIntensity = 1.0
            self.startSimulation()
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
    
    /// Trigger subtle elastic hover bounce
    public func triggerHoverImpulse(force: Double = 6.0) {
        DispatchQueue.main.async {
            self.amplitude = force
            self.time = 0.0
            self.startSimulation()
        }
    }
    
    private func startSimulation() {
        displayTimer?.invalidate()
        
        // 60fps physics simulation loop
        let dt = 1.0 / 60.0
        displayTimer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.time += dt
            
            // Damped harmonic oscillation: A * e^(-damping * t) * sin(frequency * t)
            let decay = exp(-self.damping * self.time)
            let oscillation = sin(self.frequency * self.time)
            let currentDeform = self.amplitude * decay * oscillation
            
            // Volumetric conservation: when y expands, x compresses slightly; when y rebounds, x bulges
            let currentBulge = -currentDeform * 0.45
            
            self.jellyY = CGFloat(currentDeform)
            self.jellyX = CGFloat(currentBulge)
            self.rippleIntensity = CGFloat(max(0.0, 1.0 - (self.time * 2.5)))
            
            // Terminate simulation once oscillation has settled below 0.1pt
            if abs(currentDeform) < 0.1 && self.time > 0.3 {
                self.jellyY = 0.0
                self.jellyX = 0.0
                self.rippleIntensity = 0.0
                timer.invalidate()
                self.displayTimer = nil
            }
        }
    }
}

/// Dynamic canvas fluid ripple overlay drawn at the point of drop impact
public struct FluidRippleCanvas: View {
    public let intensity: CGFloat
    
    public init(intensity: CGFloat) {
        self.intensity = intensity
    }
    
    public var body: some View {
        if intensity > 0.01 {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2.0, y: size.height - 6)
                let maxRadius = size.width * 0.6
                let waveCount = 3
                
                for i in 0..<waveCount {
                    let progress = (1.0 - Double(intensity)) + (Double(i) * 0.15)
                    let r = maxRadius * CGFloat(progress)
                    let alpha = Double(intensity) * (1.0 - progress) * 0.4
                    
                    var path = Path()
                    path.addArc(
                        center: center,
                        radius: r,
                        startAngle: .degrees(180),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                    
                    context.stroke(
                        path,
                        with: .color(Color.cyan.opacity(alpha)),
                        lineWidth: 2.0 * intensity
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}
