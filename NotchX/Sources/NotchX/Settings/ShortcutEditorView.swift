import SwiftUI

struct ShortcutEditorView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var sheetState = ShortcutSheetState()
    
    var body: some View {
        VStack {
            List {
                ForEach(settings.shortcuts) { shortcut in
                    HStack {
                        Image(systemName: shortcut.icon)
                            .foregroundColor(Color(hex: shortcut.colorHex) ?? .primary)
                            .frame(width: 24)
                        Text(shortcut.name)
                        Spacer()
                        Text(shortcut.actionType.rawValue)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Button(action: {
                            settings.shortcuts.removeAll { $0.id == shortcut.id }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
                .onMove { indices, newOffset in
                    settings.shortcuts.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .listStyle(InsetListStyle())
            
            HStack {
                Text("\(settings.shortcuts.count)/8 Shortcuts")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Shortcut") {
                    sheetState.isPresented = true
                }
                .disabled(settings.shortcuts.count >= 8)
            }
            .padding()
        }
        .sheet(isPresented: $sheetState.isPresented) {
            AddShortcutSheet(viewModel: AddShortcutViewModel()) { newShortcut in
                settings.shortcuts.append(newShortcut)
            }
        }
    }
}

/// Observable state for controlling the sheet presentation
class ShortcutSheetState: ObservableObject {
    @Published var isPresented = false
}

/// Observable view model for the add-shortcut form, avoids @State macros
class AddShortcutViewModel: ObservableObject {
    @Published var name = ""
    @Published var icon = "star.fill"
    @Published var actionType: ShortcutActionType = .launchApp
    @Published var actionData = ""
    @Published var shouldDismiss = false
}

struct AddShortcutSheet: View {
    @ObservedObject var viewModel: AddShortcutViewModel
    var onAdd: (ShortcutItem) -> Void
    
    let commonSymbols = [
        "star.fill", "safari", "terminal", "folder", "gear",
        "envelope", "message", "calendar", "music.note",
        "globe", "camera.viewfinder", "lock.fill", "moon.circle.fill",
        "bolt.fill", "link", "doc", "trash"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Shortcut")
                .font(.headline)
            
            Form {
                TextField("Name", text: $viewModel.name)
                
                Picker("Action Type", selection: $viewModel.actionType) {
                    ForEach(ShortcutActionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                TextField(actionDataPlaceholder, text: $viewModel.actionData)
                
                Picker("Icon", selection: $viewModel.icon) {
                    ForEach(commonSymbols, id: \.self) { symbol in
                        Label(symbol, systemImage: symbol).tag(symbol)
                    }
                }
            }
            .frame(width: 300)
            
            HStack {
                Button("Cancel") {
                    viewModel.shouldDismiss = true
                }
                Button("Add") {
                    let item = ShortcutItem(
                        name: viewModel.name.isEmpty ? "New Shortcut" : viewModel.name,
                        icon: viewModel.icon,
                        actionType: viewModel.actionType,
                        actionData: viewModel.actionData,
                        colorHex: "#007AFF"
                    )
                    onAdd(item)
                    viewModel.shouldDismiss = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350, height: 320)
    }
    
    private var actionDataPlaceholder: String {
        switch viewModel.actionType {
        case .launchApp: return "App Bundle ID (e.g., com.apple.Safari)"
        case .openURL: return "URL (e.g., https://google.com)"
        case .systemAction: return "Action (e.g., Screenshot)"
        case .shortcutsApp: return "Shortcut Name"
        case .appleScript: return "AppleScript Code / Macro"
        }
    }
}
