// Copyright © 2026 Vedant. All rights reserved.
import SwiftUI
import AppKit

/// Observable view model for the inline shortcut builder, avoiding @State macro
class InlineShortcutBuilderModel: ObservableObject {
    static let shared = InlineShortcutBuilderModel()
    
    @Published var isCreatorOpen: Bool = false
    @Published var name: String = ""
    @Published var icon: String = "star.fill"
    @Published var actionType: ShortcutActionType = .launchApp
    @Published var actionData: String = ""
    @Published var selectedColorHex: String = "#007AFF"
    
    let availableColors: [String] = [
        "#007AFF", // Blue
        "#AF52DE", // Purple
        "#FF2D55", // Pink
        "#FF9500", // Orange
        "#34C759", // Green
        "#5AC8FA"  // Cyan
    ]
    
    let commonSymbols: [String] = [
        "safari", "terminal", "folder.fill", "gearshape.fill",
        "envelope.fill", "message.fill", "calendar", "music.note",
        "camera.viewfinder", "lock.fill", "sparkles", "bolt.fill",
        "link", "doc.fill", "waveform", "star.fill"
    ]
    
    func reset() {
        name = ""
        icon = "safari"
        actionType = .launchApp
        actionData = ""
        selectedColorHex = "#007AFF"
        isCreatorOpen = false
    }
}

/// Ultra-modern, fully inline Shortcut Editor for NotchX
/// Eliminates broken macOS modal sheets and nested Lists for 100% reliable shortcut management.
struct ShortcutEditorView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var builder = InlineShortcutBuilderModel.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Count & Add Button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "command")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                    Text("CONFIGURED SHORTCUTS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(0.6)
                }
                
                Spacer()
                
                Text("\(settings.shortcuts.count)/8 Active")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                
                Button(action: {
                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        builder.isCreatorOpen.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: builder.isCreatorOpen ? "xmark" : "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text(builder.isCreatorOpen ? "Cancel" : "Add Shortcut")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(builder.isCreatorOpen ? Color.white.opacity(0.12) : Color.blue.opacity(0.20))
                    .foregroundColor(builder.isCreatorOpen ? .white : .blue)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(builder.isCreatorOpen ? Color.white.opacity(0.2) : Color.blue.opacity(0.4), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .disabled(settings.shortcuts.count >= 8 && !builder.isCreatorOpen)
            }
            
            // Inline Creator Drawer
            if builder.isCreatorOpen {
                inlineCreatorCard
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                    ))
            }
            
            // Existing Shortcuts List (Card-based, no broken List inside ScrollView!)
            if settings.shortcuts.isEmpty {
                emptyState
            } else {
                VStack(spacing: 7) {
                    ForEach(settings.shortcuts) { shortcut in
                        shortcutRow(shortcut: shortcut)
                    }
                }
            }
        }
    }
    
    // MARK: - Shortcut Row Card
    
    private func shortcutRow(shortcut: ShortcutItem) -> some View {
        HStack(spacing: 10) {
            // Icon Emblem
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: shortcut.colorHex) ?? Color.blue)
                    .shadow(color: (Color(hex: shortcut.colorHex) ?? Color.blue).opacity(0.35), radius: 3)
                
                Image(systemName: shortcut.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 26, height: 26)
            
            // Details
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 6) {
                    Text(shortcut.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(shortcut.actionType.rawValue)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.60))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                
                if !shortcut.actionData.isEmpty {
                    Text(shortcut.actionData)
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Test Run Button
            Button(action: {
                AuralHapticsManager.shared.play(.sparkleTick, haptic: .alignment)
                ShortcutExecutor.execute(shortcut)
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.80))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Test execute shortcut")
            
            // Delete Button
            Button(action: {
                AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    settings.shortcuts.removeAll { $0.id == shortcut.id }
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 9.5))
                    .foregroundColor(.red.opacity(0.85))
                    .frame(width: 22, height: 22)
                    .background(Color.red.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Delete shortcut")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 0.75)
                )
        )
    }
    
    // MARK: - Inline Creator Card
    
    private var inlineCreatorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NEW SHORTCUT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .tracking(0.6)
                Spacer()
            }
            
            // Name Field
            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("Shortcut name (e.g. Safari, Open Site, Screenshot)", text: $builder.name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Action Type Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Action Type")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Picker("", selection: $builder.actionType) {
                    ForEach(ShortcutActionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
            }
            
            // Action Data
            VStack(alignment: .leading, spacing: 4) {
                Text("Action Target")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField(placeholderForType(builder.actionType), text: $builder.actionData)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Icon Picker Grid
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose Icon")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(builder.commonSymbols.prefix(8), id: \.self) { sym in
                        iconButton(symbol: sym)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(builder.commonSymbols.suffix(8), id: \.self) { sym in
                        iconButton(symbol: sym)
                    }
                }
            }
            
            // Color Palette
            VStack(alignment: .leading, spacing: 6) {
                Text("Icon Color")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(builder.availableColors, id: \.self) { hex in
                        Button(action: {
                            builder.selectedColorHex = hex
                            AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: hex) ?? .blue)
                                    .frame(width: 22, height: 22)
                                if builder.selectedColorHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider().padding(.vertical, 2)
            
            // Save & Cancel Buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        builder.reset()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: saveShortcut) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Add to Notch")
                    }
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(builder.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.blue.opacity(0.35), lineWidth: 1)
                )
        )
    }
    
    private func iconButton(symbol: String) -> some View {
        Button(action: {
            builder.icon = symbol
            AuralHapticsManager.shared.play(.tock, haptic: .alignment)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(builder.icon == symbol ? Color.blue.opacity(0.35) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(builder.icon == symbol ? Color.blue : Color.clear, lineWidth: 1)
                    )
                
                Image(systemName: symbol)
                    .font(.system(size: 11))
                    .foregroundColor(builder.icon == symbol ? .white : .white.opacity(0.70))
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
    }
    
    private func placeholderForType(_ type: ShortcutActionType) -> String {
        switch type {
        case .launchApp: return "Bundle ID (e.g. com.apple.Safari) or App Name"
        case .openURL: return "URL (e.g. https://github.com)"
        case .systemAction: return "Action: Screenshot, Lock Screen, Toggle DND"
        case .shortcutsApp: return "Name of shortcut in Shortcuts.app"
        case .appleScript: return "AppleScript source or Terminal command"
        }
    }
    
    private func saveShortcut() {
        let name = builder.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        let item = ShortcutItem(
            name: name,
            icon: builder.icon,
            actionType: builder.actionType,
            actionData: builder.actionData,
            colorHex: builder.selectedColorHex
        )
        
        AuralHapticsManager.shared.play(.completionChime, haptic: .levelChange)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            settings.shortcuts.append(item)
            builder.reset()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "command")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
            Text("No Shortcuts Added")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
        )
    }
}
