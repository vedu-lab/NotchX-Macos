import Foundation

enum ShortcutActionType: String, Codable, CaseIterable, Sendable {
    case launchApp = "Launch App"
    case openURL = "Open URL"
    case systemAction = "System Action"
    case shortcutsApp = "Shortcuts App"
    case appleScript = "AppleScript Macro"
}

struct ShortcutItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var icon: String           // SF Symbol name
    var actionType: ShortcutActionType
    var actionData: String     // Bundle ID for apps, URL string for URLs, action key for system, shortcut name for Shortcuts.app
    var colorHex: String       // Hex color string for icon background
    
    init(id: UUID = UUID(), name: String, icon: String, actionType: ShortcutActionType, actionData: String, colorHex: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.actionType = actionType
        self.actionData = actionData
        self.colorHex = colorHex
    }
    
    // Provide default shortcuts
    static var defaults: [ShortcutItem] {
        [
            ShortcutItem(name: "Safari", icon: "safari", actionType: .launchApp, actionData: "com.apple.Safari", colorHex: "#007AFF"),
            ShortcutItem(name: "Finder", icon: "macwindow", actionType: .launchApp, actionData: "com.apple.finder", colorHex: "#007AFF"),
            ShortcutItem(name: "Terminal", icon: "terminal", actionType: .launchApp, actionData: "com.apple.Terminal", colorHex: "#000000"),
            ShortcutItem(name: "Settings", icon: "gearshape", actionType: .launchApp, actionData: "com.apple.systempreferences", colorHex: "#8E8E93"),
            ShortcutItem(name: "Screenshot", icon: "camera.viewfinder", actionType: .systemAction, actionData: "Screenshot", colorHex: "#34C759")
        ]
    }
}
