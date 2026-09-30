import SwiftUI

@MainActor
struct ShortcutExecutor {
    static func execute(_ shortcut: ShortcutItem) {
        AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
        switch shortcut.actionType {
        case .launchApp:
            AppLauncher.launch(bundleID: shortcut.actionData)
        case .openURL:
            URLAction.open(urlString: shortcut.actionData)
        case .systemAction:
            if let action = SystemAction(rawValue: shortcut.actionData) {
                action.execute()
            }
        case .shortcutsApp:
            ShortcutsRunner.run(shortcutName: shortcut.actionData)
        case .appleScript:
            _ = NSAppleScript(source: shortcut.actionData)?.executeAndReturnError(nil)
        }
    }
}

/// Shortcuts tray with transparent background — wallpaper shows through
struct ShortcutsTray: View {
    let shortcuts: [ShortcutItem]
    let onExecute: (ShortcutItem) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(shortcuts) { shortcut in
                    Button(action: {
                        onExecute(shortcut)
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: shortcut.icon)
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 42, height: 42)
                                .background(
                                    (Color(hex: shortcut.colorHex) ?? Color.blue).opacity(0.7)
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            
                            Text(shortcut.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                        .frame(width: 56)
                    }
                    .buttonStyle(TrayButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}

struct TrayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
