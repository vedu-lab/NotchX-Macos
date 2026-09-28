import AppKit
import SwiftUI

/// Window controller for the dedicated NotchX Settings window.
/// Brings the settings window forward even when NotchX is running as an accessory app.
@MainActor
class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    
    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 740, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "NotchX Settings"
            window.titlebarAppearsTransparent = false
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 680, height: 460)
            self.window = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
