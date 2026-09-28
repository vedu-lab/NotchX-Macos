import AppKit

struct URLAction {
    static func open(urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
