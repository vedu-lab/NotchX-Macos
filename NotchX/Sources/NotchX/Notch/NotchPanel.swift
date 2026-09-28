import AppKit

/// Borderless, non-activating floating panel configured with Atoll's window traits.
/// Positioned at `.mainMenu + 3` to float seamlessly above the menu bar across all spaces.
class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.isOpaque = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isMovable = false
        
        self.collectionBehavior = [
            .fullScreenAuxiliary,
            .canJoinAllSpaces,
            .ignoresCycle,
            .stationary
        ]
        
        self.isReleasedWhenClosed = false
        self.level = .mainMenu + 3
        self.hasShadow = false
        self.animationBehavior = .none
        self.ignoresMouseEvents = false
        
        self.registerForDraggedTypes([
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
    
    override var canBecomeKey: Bool {
        true
    }
    
    override var canBecomeMain: Bool {
        true
    }
}
