import AppKit
import SwiftUI

/// Custom NSHostingView that supports First Mouse (instant click without window activation)
/// and passes clicks outside the visible notch contour through to macOS and underlying apps.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    weak var viewModel: NotchViewModel?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.item"),
            NSPasteboard.PasteboardType("public.content"),
            NSPasteboard.PasteboardType("public.data"),
            NSPasteboard.PasteboardType("public.image"),
            .png,
            .tiff
        ])
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
    
    // Intercept drags so macOS does NOT open background windows or trigger Exposé / Mission Control
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        DispatchQueue.main.async {
            self.viewModel?.setHovered(true)
            NotificationCenter.default.post(name: NSNotification.Name("NotchDidReceiveDrag"), object: nil)
        }
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        var urls: [URL] = []
        
        if let readURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            urls.append(contentsOf: readURLs)
        }
        
        if urls.isEmpty, let paths = pasteboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
            for path in paths {
                urls.append(URL(fileURLWithPath: path))
            }
        }
        
        if !urls.isEmpty {
            DispatchQueue.main.async {
                NotchPhysicsEngine.shared.triggerDropImpact()
                for url in urls {
                    FileTrayManager.shared.addFile(url: url)
                }
                NotificationCenter.default.post(name: NSNotification.Name("NotchDidReceiveDrag"), object: nil)
            }
            return true
        }
        return false
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let vm = viewModel else { return super.hitTest(point) }
        
        let bounds = self.bounds
        let localPoint = superview != nil ? convert(point, from: superview) : point
        
        let isExp = vm.isExpanded
        let settings = SettingsManager.shared
        let isHUD = SystemHUDManager.shared.isVisible
        
        let activeW: CGFloat = isExp
            ? settings.notchExpandedWidth
            : (isHUD ? 284 : max(NotchDetector.notchWidth(), 180))
            
        let activeH: CGFloat = isExp
            ? (settings.notchExpandedHeight + 4)
            : (isHUD ? 50 : (max(NotchDetector.notchHeight(), 32) + 4))
            
        let minX = (bounds.width - activeW) / 2
        let maxX = minX + activeW
        let minY = bounds.height - activeH
        let maxY = bounds.height
        
        if localPoint.x >= minX && localPoint.x <= maxX && localPoint.y >= minY && localPoint.y <= maxY {
            return super.hitTest(point)
        }
        
        // Pass event through to window underneath
        return nil
    }
}

/// Manages the notch overlay panel lifecycle, placement, and sizing inspired by Atoll:
/// - Screen-anchored positioning with +4px top bleed to eliminate subpixel gap
/// - Compact window when closed (zero screen blockage)
/// - Expands window smoothly when opened
@MainActor
class NotchWindowController {
    static let shared = NotchWindowController()
    var panel: NotchPanel?
    var viewModel = NotchViewModel()
    
    /// Top screen bleed amount matching Atoll to ensure zero gap at the top bezel
    let topBleed: CGFloat = 4
    
    private var windowCloseTimer: DispatchWorkItem?
    
    init() {
        setupPanel()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    func setupPanel() {
        guard let screen = NSScreen.main else { return }
        let initialSize = closedSize(for: screen)
        let initialFrame = calculateFrame(for: initialSize, on: screen)
        
        panel = NotchPanel(contentRect: initialFrame)
        
        let contentView = NotchContentView(viewModel: viewModel)
        let hosting = FirstMouseHostingView(rootView: contentView)
        hosting.viewModel = viewModel
        hosting.frame = NSRect(origin: .zero, size: initialFrame.size)
        panel?.contentView = hosting
        
        // Wire up size change handler from viewModel
        viewModel.onExpansionStateChange = { [weak self] isOpening in
            self?.handleExpansionStateChange(isOpening: isOpening)
        }
    }
    
    func showNotch() {
        panel?.orderFrontRegardless()
    }
    
    func hideNotch() {
        panel?.orderOut(nil)
    }
    
    func closedSize(for screen: NSScreen) -> CGSize {
        let w = max(NotchDetector.notchWidth(screen: screen), 180)
        let h = max(NotchDetector.notchHeight(screen: screen), 32) + topBleed
        return CGSize(width: w, height: h)
    }
    
    func openSize(for screen: NSScreen) -> CGSize {
        let settings = SettingsManager.shared
        return CGSize(
            width: settings.notchExpandedWidth,
            height: settings.notchExpandedHeight + topBleed
        )
    }
    
    func calculateFrame(for size: CGSize, on screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let clampedWidth = min(size.width, screenFrame.width).rounded()
        let clampedHeight = min(size.height, screenFrame.height + topBleed).rounded()
        let centerX = screenFrame.midX
        let newX = (centerX - (clampedWidth / 2)).rounded()
        let newY = (screenFrame.maxY + topBleed - clampedHeight).rounded()
        return NSRect(x: newX, y: newY, width: clampedWidth, height: clampedHeight)
    }
    
    func handleExpansionStateChange(isOpening: Bool) {
        windowCloseTimer?.cancel()
        guard let screen = NSScreen.main, let panel = panel else { return }
        
        if isOpening {
            // Expand window immediately so SwiftUI spring animation can render
            let targetSize = openSize(for: screen)
            let targetFrame = calculateFrame(for: targetSize, on: screen)
            if panel.frame != targetFrame {
                panel.setFrame(targetFrame, display: true)
                panel.contentView?.frame = NSRect(origin: .zero, size: targetFrame.size)
            }
        } else {
            // Wait for SwiftUI spring close animation to finish (400ms) before shrinking window back
            let work = DispatchWorkItem { [weak self] in
                guard let self = self, let screen = NSScreen.main, let panel = self.panel else { return }
                let targetSize = self.closedSize(for: screen)
                let targetFrame = self.calculateFrame(for: targetSize, on: screen)
                if panel.frame != targetFrame {
                    panel.setFrame(targetFrame, display: true)
                    panel.contentView?.frame = NSRect(origin: .zero, size: targetFrame.size)
                }
            }
            windowCloseTimer = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: work)
        }
    }
    
    func updateHUDState(visible: Bool) {
        guard !viewModel.isExpanded, let screen = NSScreen.main, let panel = panel else { return }
        
        let targetSize: CGSize
        if visible {
            let w = max(NotchDetector.notchWidth(screen: screen), 196) + 88 // ~288pt
            let h = max(NotchDetector.notchHeight(screen: screen), 34) + topBleed + 18 // ~56pt
            targetSize = CGSize(width: w, height: h)
        } else {
            targetSize = closedSize(for: screen)
        }
        
        let targetFrame = calculateFrame(for: targetSize, on: screen)
        if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: true)
            panel.contentView?.frame = NSRect(origin: .zero, size: targetFrame.size)
        }
    }
    
    @objc func screenParametersDidChange() {
        Task { @MainActor in
            guard let screen = NSScreen.main else { return }
            let size = viewModel.isExpanded ? openSize(for: screen) : closedSize(for: screen)
            let targetFrame = calculateFrame(for: size, on: screen)
            panel?.setFrame(targetFrame, display: true)
            panel?.contentView?.frame = NSRect(origin: .zero, size: targetFrame.size)
            showNotch()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
