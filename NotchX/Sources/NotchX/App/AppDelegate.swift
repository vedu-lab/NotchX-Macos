import AppKit
import SwiftUI

/// Application delegate that bootstraps the notch overlay and menu bar
@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    var notchController: NotchWindowController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 0. Activate Anti-Tamper & Security Shield
        AppSecurityManager.shared.activateSecurityShield()
        
        // Hide from dock — accessory app (menu bar only)
        NSApp.setActivationPolicy(.accessory)
        
        // Setup menu bar icon
        MenuBarManager.shared.setup()
        
        // Setup notch overlay
        setupNotchOverlay()
        
        // Listen for screen changes (external monitor connect/disconnect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    private func setupNotchOverlay() {
        if notchController == nil {
            notchController = NotchWindowController()
        }
        notchController?.showNotch()
    }
    
    @objc private func screenParametersChanged() {
        notchController?.screenParametersDidChange()
    }
}
