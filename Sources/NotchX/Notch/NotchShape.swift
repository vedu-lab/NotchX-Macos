import SwiftUI

/// Custom SwiftUI Shape modeling the MacBook camera notch with Apple's exact curvature.
/// Directly inspired by Atoll and Boring Notch:
/// - Exact quadratic curves at top-left and top-right flaring into the display bezel
/// - Smooth bottom corner curves
/// - Animatable top and bottom radii
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    
    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 14) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }
    
    init(progress: CGFloat) {
        // Interpolate between closed (6, 14) and open (10, 22)
        self.topCornerRadius = 6 + (4 * progress)
        self.bottomCornerRadius = 14 + (8 * progress)
    }
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            .init(topCornerRadius, bottomCornerRadius)
        }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 1. Start at top-left on the display bezel
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // 2. Top-left concave wing: smooth G2 continuous bezier from horizontal bezel down to vertical edge
        path.addCurve(
            to: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.minY + topCornerRadius
            ),
            control1: CGPoint(
                x: rect.minX + (topCornerRadius * 0.45),
                y: rect.minY
            ),
            control2: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.minY + (topCornerRadius * 0.55)
            )
        )
        
        // 3. Left vertical edge
        path.addLine(
            to: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.maxY - bottomCornerRadius
            )
        )
        
        // 4. Bottom-left continuous rounded corner into horizontal bottom edge
        path.addCurve(
            to: CGPoint(
                x: rect.minX + topCornerRadius + bottomCornerRadius,
                y: rect.maxY
            ),
            control1: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.maxY - (bottomCornerRadius * 0.45)
            ),
            control2: CGPoint(
                x: rect.minX + topCornerRadius + (bottomCornerRadius * 0.45),
                y: rect.maxY
            )
        )
        
        // 5. Bottom horizontal edge
        path.addLine(
            to: CGPoint(
                x: rect.maxX - topCornerRadius - bottomCornerRadius,
                y: rect.maxY
            )
        )
        
        // 6. Bottom-right continuous rounded corner into vertical edge
        path.addCurve(
            to: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.maxY - bottomCornerRadius
            ),
            control1: CGPoint(
                x: rect.maxX - topCornerRadius - (bottomCornerRadius * 0.45),
                y: rect.maxY
            ),
            control2: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.maxY - (bottomCornerRadius * 0.45)
            )
        )
        
        // 7. Right vertical edge
        path.addLine(
            to: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.minY + topCornerRadius
            )
        )
        
        // 8. Top-right concave wing curving out to the horizontal bezel
        path.addCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.minY
            ),
            control1: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.minY + (topCornerRadius * 0.55)
            ),
            control2: CGPoint(
                x: rect.maxX - (topCornerRadius * 0.45),
                y: rect.minY
            )
        )
        
        // 9. Close along the top screen bezel back to (rect.minX, rect.minY)
        path.addLine(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )
        
        return path
    }
}
