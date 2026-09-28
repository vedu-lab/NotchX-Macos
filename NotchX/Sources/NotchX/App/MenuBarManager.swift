import AppKit

@MainActor
public class MenuBarManager {
    public static let shared = MenuBarManager()
    private var statusItem: NSStatusItem!
    
    private init() {}
    
    public func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = createMenuIcon()
            button.imagePosition = .imageOnly
        }
        
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit NotchX", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func createMenuIcon() -> NSImage {
        // 1. Try loading from app bundle resources
        if let url = Bundle.main.url(forResource: "NXMenuIcon@2x", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 18, height: 11)
            img.isTemplate = true
            return img
        }
        
        // 2. Try direct source path fallback
        let fallbackPath = "/Users/vedant/Documents/Bleach/NotchX/Sources/NotchX/Resources/NXMenuIcon@2x.png"
        if let img = NSImage(contentsOfFile: fallbackPath) {
            img.size = NSSize(width: 18, height: 11)
            img.isTemplate = true
            return img
        }
        
        // 3. Fallback to standard symbol
        let symbol = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: "NotchX") ?? NSImage()
        symbol.isTemplate = true
        return symbol
    }
}
