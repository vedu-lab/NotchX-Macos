import Foundation
import AppKit
import ApplicationServices
import Combine

/// Sectors for snapping windows into organized layouts
public enum SnapSector: String, CaseIterable, Identifiable {
    case leftHalf = "Left 50%"
    case rightHalf = "Right 50%"
    case leftThird = "Left 33%"
    case centerThird = "Center 33%"
    case rightThird = "Right 33%"
    case leftTwoThirds = "Left 66%"
    case rightTwoThirds = "Right 66%"
    case fullScreen = "Maximize"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .leftHalf: return "rectangle.split.2x1"
        case .rightHalf: return "rectangle.split.2x1.fill"
        case .leftThird: return "rectangle.split.3x1"
        case .centerThird: return "rectangle.center.inset.filled"
        case .rightThird: return "rectangle.split.3x1.fill"
        case .leftTwoThirds: return "rectangle.righthalf.inset.filled"
        case .rightTwoThirds: return "rectangle.lefthalf.inset.filled"
        case .fullScreen: return "arrow.up.left.and.arrow.down.right"
        }
    }
}

/// Manages universal window snapping & tiling.
/// When dragging a window to the top edge, the notch expands into Snap Zones.
/// Dropping or clicking any sector tiles the frontmost window immediately.
public class WindowTilingManager: ObservableObject {
    public static let shared = WindowTilingManager()
    
    @Published public var isSnappingActive: Bool = false
    @Published public var activeHoveredSector: SnapSector? = nil
    
    private var monitorTimer: Timer?
    private var isDraggingWindow: Bool = false
    
    private init() {}
    
    deinit {
        monitorTimer?.invalidate()
    }
    
    public func startDragMonitoring() {
        // Disabled per user request
    }
    
    private func checkMouseDragPosition() {
        let mouseButtons = NSEvent.pressedMouseButtons
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        
        // Window drag detection: Left mouse button is down AND cursor is near top of screen
        let isTopEdge = mouseLoc.y >= (screen.frame.maxY - 50)
        let isNearNotch = abs(mouseLoc.x - screen.frame.midX) <= 220 && mouseLoc.y >= (screen.frame.maxY - 70)
        
        let currentlyDragging = (mouseButtons & 1) != 0 && (isTopEdge || isNearNotch)
        
        if currentlyDragging && !isSnappingActive {
            // Check if not dragging a file (files are handled by FileTray)
            let pb = NSPasteboard(name: .drag)
            let hasFiles = pb.types?.contains(.fileURL) ?? false
            if !hasFiles {
                DispatchQueue.main.async {
                    self.isSnappingActive = true
                    self.isDraggingWindow = true
                }
            }
        } else if !currentlyDragging && isDraggingWindow {
            // Mouse released! If cursor was hovering over a sector, snap immediately!
            isDraggingWindow = false
            if let targetSector = activeHoveredSector {
                DispatchQueue.main.async {
                    self.snapFrontmostWindow(to: targetSector)
                    self.isSnappingActive = false
                    self.activeHoveredSector = nil
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if !self.isDraggingWindow {
                        self.isSnappingActive = false
                    }
                }
            }
        }
    }
    
    /// Snap the frontmost active application window to a specific layout sector
    public func snapFrontmostWindow(to sector: SnapSector, screen: NSScreen? = NSScreen.main) {
        guard let screen = screen else { return }
        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame
        
        // Calculate destination frame in Cocoa coordinates (bottom-left origin)
        var targetRect: CGRect
        
        switch sector {
        case .leftHalf:
            targetRect = CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2.0,
                height: visibleFrame.height
            )
        case .rightHalf:
            targetRect = CGRect(
                x: visibleFrame.minX + (visibleFrame.width / 2.0),
                y: visibleFrame.minY,
                width: visibleFrame.width / 2.0,
                height: visibleFrame.height
            )
        case .leftThird:
            targetRect = CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 3.0,
                height: visibleFrame.height
            )
        case .centerThird:
            targetRect = CGRect(
                x: visibleFrame.minX + (visibleFrame.width / 3.0),
                y: visibleFrame.minY,
                width: visibleFrame.width / 3.0,
                height: visibleFrame.height
            )
        case .rightThird:
            targetRect = CGRect(
                x: visibleFrame.minX + (2.0 * visibleFrame.width / 3.0),
                y: visibleFrame.minY,
                width: visibleFrame.width / 3.0,
                height: visibleFrame.height
            )
        case .leftTwoThirds:
            targetRect = CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: (2.0 * visibleFrame.width) / 3.0,
                height: visibleFrame.height
            )
        case .rightTwoThirds:
            targetRect = CGRect(
                x: visibleFrame.minX + (visibleFrame.width / 3.0),
                y: visibleFrame.minY,
                width: (2.0 * visibleFrame.width) / 3.0,
                height: visibleFrame.height
            )
        case .fullScreen:
            targetRect = visibleFrame
        }
        
        // Convert to Accessibility / Carbon coordinates (top-left origin of primary display)
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? fullFrame.height
        let axX = targetRect.origin.x
        let axY = primaryScreenHeight - targetRect.origin.y - targetRect.size.height
        let axWidth = targetRect.size.width
        let axHeight = targetRect.size.height
        
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        
        // Method 1: Accessibility API
        if applyAccessibilitySnap(x: axX, y: axY, width: axWidth, height: axHeight) {
            return
        }
        
        // Method 2: AppleScript fallback
        applyAppleScriptSnap(x: Int(axX), y: Int(axY), width: Int(axWidth), height: Int(axHeight))
    }
    
    private func applyAccessibilitySnap(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppValue: AnyObject?
        let appStatus = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue)
        guard appStatus == .success, let app = focusedAppValue else { return false }
        
        let appElement = app as! AXUIElement
        var focusedWindowValue: AnyObject?
        let winStatus = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue)
        guard winStatus == .success, let window = focusedWindowValue else { return false }
        
        let winElement = window as! AXUIElement
        
        var newPoint = CGPoint(x: x, y: y)
        if let posVal = AXValueCreate(.cgPoint, &newPoint) {
            AXUIElementSetAttributeValue(winElement, kAXPositionAttribute as CFString, posVal)
        }
        
        var newSize = CGSize(width: width, height: height)
        if let sizeVal = AXValueCreate(.cgSize, &newSize) {
            AXUIElementSetAttributeValue(winElement, kAXSizeAttribute as CFString, sizeVal)
        }
        
        return true
    }
    
    private func applyAppleScriptSnap(x: Int, y: Int, width: Int, height: Int) {
        let script = """
        tell application "System Events"
            set frontApp to first application process whose frontmost is true
            tell frontApp
                if (count of windows) > 0 then
                    set position of window 1 to {\(x), \(y)}
                    set size of window 1 to {\(width), \(height)}
                end if
            end tell
        end tell
        """
        _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
    }
}
