import AppKit

struct InstalledApp: Identifiable {
    let id: String  // bundle identifier
    let name: String
    let icon: NSImage?
    let bundleURL: URL
}

@MainActor
struct AppLauncher {
    /// Launch app by bundle identifier
    static func launch(bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error = error {
                    print("Error launching app \(bundleID): \(error)")
                }
            }
        }
    }
    
    /// Get list of installed applications from /Applications and ~/Applications
    static func installedApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fm = FileManager.default
        let searchURLs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        for url in searchURLs {
            if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants, .skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "app" {
                        if let bundle = Bundle(url: fileURL), let bundleID = bundle.bundleIdentifier {
                            let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String 
                                ?? bundle.infoDictionary?["CFBundleName"] as? String 
                                ?? fileURL.deletingPathExtension().lastPathComponent
                            let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                            apps.append(InstalledApp(id: bundleID, name: name, icon: icon, bundleURL: fileURL))
                        }
                    }
                }
            }
        }
        return apps
    }
}
