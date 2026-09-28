import Foundation

/// Runs Shortcuts.app automations via the system `shortcuts` CLI
struct ShortcutsRunner {
    /// Run a shortcut by name using the `shortcuts` CLI
    static func run(shortcutName: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", shortcutName]
        try? task.run()
    }
    
    /// List available shortcuts using `shortcuts list`
    static func availableShortcuts() -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["list"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.components(separatedBy: "\n").filter { !$0.isEmpty }
            }
        } catch {
            print("[NotchX] Error listing shortcuts: \(error)")
        }
        return []
    }
}
