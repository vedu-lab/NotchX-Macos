import SwiftUI
import AppKit

/// Observable hover state avoiding broken @State macro
public class SnapHoverState: ObservableObject {
    public static let shared = SnapHoverState()
    @Published public var hoveredSector: SnapSector? = nil
}

/// Dynamic Window Snap Zones Grid
/// Appears when dragging a window towards the top of the display or via the Notch HUD.
/// Dropping into any sector instantly snaps the frontmost application window.
public struct SnapZonesOverlayView: View {
    @ObservedObject private var tilingManager = WindowTilingManager.shared
    @ObservedObject private var hover = SnapHoverState.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "uiwindow.split.2x1")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                    Text("SNAP ZONES & WINDOW TILING")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .tracking(0.8)
                }
                
                Spacer()
                
                Text("Drop or Click to Tile")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 4)
            
            // Primary Snap Grid (Row 1: Halves & Maximize)
            HStack(spacing: 8) {
                sectorCard(sector: .leftHalf, title: "Left 50%", icon: "rectangle.split.2x1")
                sectorCard(sector: .fullScreen, title: "Maximize", icon: "arrow.up.left.and.arrow.down.right")
                sectorCard(sector: .rightHalf, title: "Right 50%", icon: "rectangle.split.2x1.fill")
            }
            
            // Secondary Snap Grid (Row 2: Thirds & Two-Thirds)
            HStack(spacing: 8) {
                sectorCard(sector: .leftThird, title: "Left 1/3", icon: "rectangle.split.3x1")
                sectorCard(sector: .centerThird, title: "Center 1/3", icon: "rectangle.center.inset.filled")
                sectorCard(sector: .rightThird, title: "Right 1/3", icon: "rectangle.split.3x1.fill")
                sectorCard(sector: .leftTwoThirds, title: "Left 2/3", icon: "rectangle.righthalf.inset.filled")
                sectorCard(sector: .rightTwoThirds, title: "Right 2/3", icon: "rectangle.lefthalf.inset.filled")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    private func sectorCard(sector: SnapSector, title: String, icon: String) -> some View {
        let isHovered = hover.hoveredSector == sector || tilingManager.activeHoveredSector == sector
        
        return Button(action: {
            tilingManager.snapFrontmostWindow(to: sector)
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isHovered ? .bold : .medium))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.8))
                
                Text(title)
                    .font(.system(size: 9, weight: isHovered ? .bold : .medium))
                    .foregroundColor(isHovered ? .white : .white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isHovered
                            ? Color.blue.opacity(0.45)
                            : Color.white.opacity(0.08)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isHovered ? Color.blue.opacity(0.85) : Color.white.opacity(0.12),
                        lineWidth: isHovered ? 1.5 : 0.5
                    )
            )
            .scaleEffect(isHovered ? 1.04 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering {
                hover.hoveredSector = sector
                tilingManager.activeHoveredSector = sector
            } else if hover.hoveredSector == sector {
                hover.hoveredSector = nil
                tilingManager.activeHoveredSector = nil
            }
        }
    }
}
