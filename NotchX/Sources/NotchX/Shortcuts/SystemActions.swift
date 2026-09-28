import AppKit

enum SystemAction: String, CaseIterable, Codable, Sendable {
    case toggleDarkMode = "Toggle Dark Mode"
    case screenshot = "Screenshot"
    case lockScreen = "Lock Screen"
    case toggleDND = "Do Not Disturb"
    case emptyTrash = "Empty Trash"
    case sleepDisplay = "Sleep Display"
    
    var iconName: String {
        switch self {
        case .toggleDarkMode: return "moon.circle.fill"
        case .screenshot: return "camera.viewfinder"
        case .lockScreen: return "lock.fill"
        case .toggleDND: return "moon.zzz.fill"
        case .emptyTrash: return "trash.fill"
        case .sleepDisplay: return "display.sleep"
        }
    }
    
    func execute() {
        switch self {
        case .toggleDarkMode:
            let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        case .screenshot:
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-i", "-c"] // Interactive capture to clipboard
            try? task.run()
        case .lockScreen:
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
            task.arguments = ["-suspend"]
            try? task.run()
        case .toggleDND:
            // Toggling Focus in recent macOS via simple script/command is notoriously difficult without Shortcuts/Entitlements. 
            // Often "open x-apple.systempreferences:com.apple.preference.notifications" is a fallback, but here's a best effort
            let script = "tell application \"System Events\" to key code 145" // F12 might map differently, this is best-effort fallback
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        case .emptyTrash:
            let script = "tell application \"Finder\" to empty trash"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        case .sleepDisplay:
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            task.arguments = ["displaysleepnow"]
            try? task.run()
        }
    }
}
