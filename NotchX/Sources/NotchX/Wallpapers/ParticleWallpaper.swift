import SwiftUI

/// Particle data for the floating particle wallpaper effect
struct Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var size: Double
    var r: Double
    var g: Double
    var b: Double
    var opacity: Double
    var birth: Double
    var life: Double
}

/// A floating particle field with soft glowing dots that drift upward
/// Performance optimized: pre-allocated arrays, delta-time physics,
/// opaque canvas, reduced particle count for small notch area
struct ParticleWallpaper: View {
    @ObservedObject private var engine = ParticleEngine()
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                engine.update(now: now, canvasSize: size)
                
                // Fill background once
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                
                // Batch render all visible particles
                for particle in engine.particles {
                    let age = now - particle.birth
                    guard age > 0 && age < particle.life else { continue }
                    
                    // Smooth fade in/out
                    let fadeIn = min(age * 2.0, 1.0)
                    let fadeOut = min((particle.life - age) * 1.5, 1.0)
                    let alpha = particle.opacity * fadeIn * fadeOut
                    
                    guard alpha > 0.01 else { continue }
                    
                    let halfSize = particle.size * 0.5
                    let rect = CGRect(
                        x: particle.x - halfSize,
                        y: particle.y - halfSize,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    let color = Color(red: particle.r, green: particle.g, blue: particle.b).opacity(alpha)
                    context.fill(Circle().path(in: rect), with: .color(color))
                }
            }
        }
    }
}

/// Manages particle lifecycle and physics with delta-time updates
class ParticleEngine: ObservableObject {
    // Pre-allocate for 30 particles (optimal for small notch area)
    private static let particleCount = 30
    var particles: [Particle] = []
    private var lastUpdate: Double = 0
    private var initialized = false
    
    func update(now: Double, canvasSize: CGSize) {
        if !initialized {
            initializeParticles(now: now, size: canvasSize)
            initialized = true
            lastUpdate = now
            return
        }
        
        let dt = now - lastUpdate
        guard dt > 0 && dt < 0.5 else {
            lastUpdate = now
            return
        }
        lastUpdate = now
        
        let width = Double(canvasSize.width)
        let height = Double(canvasSize.height)
        
        // Scale velocity by delta time for frame-rate independent motion
        let dtScale = dt * 60.0 // Normalize to 60fps base
        
        for i in particles.indices {
            let age = now - particles[i].birth
            if age > particles[i].life || particles[i].y < -10 {
                particles[i] = createParticle(now: now, width: width, height: height)
                continue
            }
            
            particles[i].x += particles[i].vx * dtScale
            particles[i].y += particles[i].vy * dtScale
        }
    }
    
    private func initializeParticles(now: Double, size: CGSize) {
        let width = Double(max(size.width, 10))
        let height = Double(max(size.height, 10))
        particles.reserveCapacity(Self.particleCount)
        particles = (0..<Self.particleCount).map { _ in
            var p = createParticle(now: now, width: width, height: height)
            p.y = Double.random(in: 0...height)
            p.birth = now - Double.random(in: 0...p.life * 0.8)
            return p
        }
    }
    
    private func createParticle(now: Double, width: Double, height: Double) -> Particle {
        let colorOptions: [(Double, Double, Double)] = [
            (1.0, 1.0, 1.0),       // white
            (0.4, 0.9, 1.0),       // cyan
            (0.8, 0.6, 1.0),       // soft purple
            (0.6, 0.8, 1.0),       // light blue
        ]
        let color = colorOptions[Int.random(in: 0..<colorOptions.count)]
        
        return Particle(
            x: Double.random(in: 0...width),
            y: height + Double.random(in: 0...15),
            vx: Double.random(in: -0.12...0.12),
            vy: Double.random(in: -1.0 ... -0.25),
            size: Double.random(in: 2...5),
            r: color.0, g: color.1, b: color.2,
            opacity: Double.random(in: 0.4...0.85),
            birth: now,
            life: Double.random(in: 3.0...6.0)
        )
    }
}
