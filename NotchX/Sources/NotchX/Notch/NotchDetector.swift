import AppKit

struct NotchDetector {
    /// Check if a given screen has a physical camera housing notch
    static func screenHasNotch(screen: NSScreen? = NSScreen.main) -> Bool {
        guard let screen = screen else { return false }
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0 && screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
        }
        return false
    }
    
    /// Get the rectangle of the notch area in screen coordinates.
    /// Returns the exact physical notch rect if available, or a calibrated top-center rect.
    static func notchRect(screen: NSScreen? = NSScreen.main) -> NSRect {
        guard let screen = screen else { return .zero }
        
        if #available(macOS 12.0, *) {
            if let leftArea = screen.auxiliaryTopLeftArea, let rightArea = screen.auxiliaryTopRightArea, screen.safeAreaInsets.top > 0 {
                let leftMaxX = leftArea.maxX
                let rightMinX = rightArea.minX
                let width = rightMinX - leftMaxX
                let height = screen.safeAreaInsets.top
                let y = screen.frame.maxY - height
                return NSRect(x: leftMaxX, y: y, width: width, height: height)
            }
        }
        
        // Graceful fallback for non-notched or external displays: calibrated centered notch
        let defaultWidth: CGFloat = 204
        let defaultHeight: CGFloat = 34
        let x = screen.frame.midX - (defaultWidth / 2)
        let y = screen.frame.maxY - defaultHeight
        return NSRect(x: x, y: y, width: defaultWidth, height: defaultHeight)
    }
    
    /// Get the notch width
    static func notchWidth(screen: NSScreen? = NSScreen.main) -> CGFloat {
        let rect = notchRect(screen: screen)
        return rect.width > 0 ? rect.width : 204
    }
    
    /// Get the notch height (safeAreaInsets.top)
    static func notchHeight(screen: NSScreen? = NSScreen.main) -> CGFloat {
        let rect = notchRect(screen: screen)
        return rect.height > 0 ? rect.height : 34
    }
}
