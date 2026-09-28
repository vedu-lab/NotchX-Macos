import SwiftUI

/// Smoothly flowing rich color gradient animation
/// Performance optimized: opaque canvas, async rendering, minimal allocations
struct GradientWallpaper: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                // Pre-compute trig values once
                let angle = now * 0.5
                let sinAngle = sin(angle)
                let cosAngle = cos(angle)
                
                // Color channel computation — rich purples, blues, teals, magentas
                let r1 = sin(now * 0.7) * 0.25 + 0.45
                let g1 = cos(now * 0.6) * 0.15 + 0.2
                let b1 = sin(now * 0.8) * 0.4 + 0.7
                
                let r2 = cos(now * 0.4) * 0.3 + 0.7
                let g2 = sin(now * 0.5) * 0.2 + 0.25
                let b2 = cos(now * 0.9) * 0.35 + 0.85
                
                // Third color for richer gradient
                let r3 = sin(now * 0.3 + 2.0) * 0.3 + 0.5
                let g3 = cos(now * 0.45 + 1.0) * 0.25 + 0.15
                let b3 = sin(now * 0.65) * 0.3 + 0.6
                
                let color1 = Color(red: r1, green: g1, blue: b1)
                let color2 = Color(red: r2, green: g2, blue: b2)
                let color3 = Color(red: r3, green: g3, blue: b3)
                
                let gradient = Gradient(colors: [color1, color2, color3])
                let halfW = size.width * 0.5
                let halfH = size.height * 0.5
                
                let startPoint = CGPoint(
                    x: halfW + cosAngle * size.width * 0.6,
                    y: halfH + sinAngle * size.height * 0.6
                )
                let endPoint = CGPoint(
                    x: halfW - cosAngle * size.width * 0.6,
                    y: halfH - sinAngle * size.height * 0.6
                )
                
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(gradient, startPoint: startPoint, endPoint: endPoint)
                )
            }
        }
    }
}
