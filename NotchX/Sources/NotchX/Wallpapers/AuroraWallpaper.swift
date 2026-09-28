import SwiftUI

/// Aurora borealis effect using layered blurred ellipses
/// Performance optimized: uses drawLayer for isolated blur contexts,
/// pre-computes trig values, minimal allocations per frame
struct AuroraWallpaper: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                
                // Fill black background once
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                
                // Pre-compute blur radius once (proportional to smallest dimension)
                let blurRadius = min(size.width, size.height) * 0.25
                
                // Aurora layer colors with pre-baked RGBA
                let layerData: [(r: Double, g: Double, b: Double, a: Double, speedX: Double, speedY: Double, scalePhase: Double)] = [
                    (0.2, 0.8, 0.6, 0.45, 0.24, 0.36, 0.15),
                    (0.1, 0.5, 0.8, 0.40, 0.32, 0.24, 0.21),
                    (0.6, 0.3, 0.8, 0.35, 0.20, 0.28, 0.14),
                    (0.3, 0.9, 0.7, 0.40, 0.28, 0.32, 0.18),
                ]
                
                let halfW = size.width * 0.5
                let halfH = size.height * 0.5
                
                for (i, layer) in layerData.enumerated() {
                    let t = now * 0.3 + Double(i) * 1.5
                    
                    let xOffset = sin(t * layer.speedX) * size.width * 0.3
                    let yOffset = cos(t * layer.speedY) * size.height * 0.2
                    let scaleX = 1.5 + sin(t * layer.scalePhase) * 0.5
                    let scaleY = 0.8 + cos(t * layer.scalePhase * 1.4) * 0.3
                    
                    let w = size.width * scaleX
                    let h = size.height * scaleY
                    
                    let ellipseRect = CGRect(
                        x: halfW - w * 0.5 + xOffset,
                        y: halfH - h * 0.5 + yOffset,
                        width: w,
                        height: h
                    )
                    
                    // Use drawLayer to isolate blur to just this ellipse
                    context.drawLayer { layerContext in
                        layerContext.addFilter(.blur(radius: blurRadius))
                        let color = Color(red: layer.r, green: layer.g, blue: layer.b).opacity(layer.a)
                        layerContext.fill(Ellipse().path(in: ellipseRect), with: .color(color))
                    }
                }
            }
        }
    }
}
