// Copyright © 2026 Vedant. All rights reserved.
import SwiftUI
import AppKit

/// Category for the inline shortcut creation studio
enum ShortcutHubCategory: String, CaseIterable, Identifiable {
    case presets = "Quick Actions"
    case apps = "Applications"
    case web = "Web Link"
    case custom = "Custom"
    case macro = "Macro"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .presets: return "bolt.fill"
        case .apps: return "app.fill"
        case .web: return "globe"
        case .custom: return "slider.horizontal.3"
        case .macro: return "record.circle"
        }
    }
}

/// Observable state managing the shortcuts hub UI and creation studio without @State macro
class ShortcutsHubState: ObservableObject {
    static let shared = ShortcutsHubState()
    
    @Published var isAddingShortcut: Bool = false
    @Published var selectedCategory: ShortcutHubCategory = .presets
    @Published var appSearchQuery: String = ""
    @Published var hoveredItemId: UUID? = nil
    
    // Custom form fields
    @Published var customName: String = ""
    @Published var customActionType: ShortcutActionType = .systemAction
    @Published var customActionData: String = "Screenshot"
    @Published var customIcon: String = "bolt.fill"
    @Published var customColorHex: String = "#007AFF"
    
    // Web URL form fields
    @Published var webName: String = ""
    @Published var webURL: String = "https://"
    
    init() {}
    
    func resetForm() {
        customName = ""
        customActionData = "Screenshot"
        customIcon = "bolt.fill"
        customColorHex = "#007AFF"
        webName = ""
        webURL = "https://"
        appSearchQuery = ""
    }
}

/// Fully reworked Shortcuts Tab View with inline addition studio, category filtering,
/// direct item deletion, and reactive execution.
public struct ShortcutsFullTabView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var hubState = ShortcutsHubState.shared
    @ObservedObject private var appsCache = AppsCache.shared
    
    public init() {}
    
    // Standard system and app presets for 1-click addition
    private let presets: [ShortcutItem] = [
        ShortcutItem(name: "Terminal", icon: "terminal", actionType: .launchApp, actionData: "com.apple.Terminal", colorHex: "#2C2C2E"),
        ShortcutItem(name: "Screenshot", icon: "camera.viewfinder", actionType: .systemAction, actionData: "Screenshot", colorHex: "#34C759"),
        ShortcutItem(name: "Lock Screen", icon: "lock.fill", actionType: .systemAction, actionData: "Lock Screen", colorHex: "#FF3B30"),
        ShortcutItem(name: "Dark Mode", icon: "moon.circle.fill", actionType: .systemAction, actionData: "Toggle Dark Mode", colorHex: "#5856D6"),
        ShortcutItem(name: "Notes", icon: "note.text", actionType: .launchApp, actionData: "com.apple.Notes", colorHex: "#FF9500"),
        ShortcutItem(name: "Messages", icon: "message.fill", actionType: .launchApp, actionData: "com.apple.MobileSMS", colorHex: "#34C759"),
        ShortcutItem(name: "Mail", icon: "envelope.fill", actionType: .launchApp, actionData: "com.apple.mail", colorHex: "#007AFF"),
        ShortcutItem(name: "Calculator", icon: "plus.forwardslash.minus", actionType: .launchApp, actionData: "com.apple.calculator", colorHex: "#FF9500"),
        ShortcutItem(name: "VS Code", icon: "chevron.left.forwardslash.chevron.right", actionType: .launchApp, actionData: "com.microsoft.VSCode", colorHex: "#007ACC"),
        ShortcutItem(name: "Spotify", icon: "music.note.list", actionType: .launchApp, actionData: "com.spotify.client", colorHex: "#1DB954"),
        ShortcutItem(name: "Safari", icon: "safari", actionType: .launchApp, actionData: "com.apple.Safari", colorHex: "#007AFF"),
        ShortcutItem(name: "Do Not Disturb", icon: "moon.zzz.fill", actionType: .systemAction, actionData: "Do Not Disturb", colorHex: "#5856D6"),
        ShortcutItem(name: "Empty Trash", icon: "trash.fill", actionType: .systemAction, actionData: "Empty Trash", colorHex: "#8E8E93"),
        ShortcutItem(name: "Sleep Display", icon: "display.sleep", actionType: .systemAction, actionData: "Sleep Display", colorHex: "#3A3A3C"),
        ShortcutItem(name: "Finder", icon: "macwindow", actionType: .launchApp, actionData: "com.apple.finder", colorHex: "#007AFF")
    ]
    
    private let commonSymbols: [String] = [
        "bolt.fill", "star.fill", "terminal", "safari", "gearshape.fill",
        "lock.fill", "camera.viewfinder", "moon.fill", "globe", "folder.fill",
        "music.note", "waveform.path.ecg", "heart.fill", "flame.fill", "sparkles", "tray.fill"
    ]
    
    private let paletteColors: [String] = [
        "#007AFF", "#5856D6", "#AF52DE", "#FF2D55",
        "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#8E8E93"
    ]
    
    public var body: some View {
        VStack(spacing: 8) {
            if hubState.isAddingShortcut {
                addStudioView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            } else {
                mainHubView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: hubState.isAddingShortcut)
    }
    
    // MARK: - Main Hub View (List Mode)
    
    private var mainHubView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                    Text("SHORTCUTS ENGINE")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.90))
                        .tracking(0.8)
                    
                    Text("\(settings.shortcuts.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                Button(action: {
                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        hubState.resetForm()
                        hubState.isAddingShortcut = true
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Add Shortcut")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Color.orange.opacity(0.24))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.orange.opacity(0.35), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            
            // Shortcuts Scroll Area
            if settings.shortcuts.isEmpty {
                emptyStateView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 11) {
                        ForEach(settings.shortcuts) { item in
                            shortcutCard(item: item)
                        }
                        
                        // Dashed New Card at the end
                        newShortcutCardButton
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Shortcut Card
    
    private func shortcutCard(item: ShortcutItem) -> some View {
        let isHovered = hubState.hoveredItemId == item.id
        let baseColor = Color(hex: item.colorHex) ?? Color.blue
        
        return ZStack(alignment: .topTrailing) {
            Button(action: {
                AuralHapticsManager.shared.play(.completionChime, haptic: .levelChange)
                ShortcutExecutor.execute(item)
            }) {
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        baseColor.opacity(isHovered ? 0.55 : 0.40),
                                        baseColor.opacity(isHovered ? 0.28 : 0.16)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 58, height: 58)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(isHovered ? 0.35 : 0.15), lineWidth: 0.8)
                            )
                            .shadow(color: baseColor.opacity(isHovered ? 0.45 : 0.20), radius: isHovered ? 6 : 3, y: 2)
                        
                        // Display genuine App icon if available
                        if item.actionType == .launchApp,
                           let app = appsCache.apps.first(where: { $0.id == item.actionData }),
                           let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        } else {
                            Image(systemName: item.icon)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                    }
                    
                    Text(item.name)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(1)
                        .frame(width: 62)
                }
            }
            .buttonStyle(.plain)
            
            // Delete badge (visible on hover)
            if isHovered {
                Button(action: {
                    AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        settings.shortcuts.removeAll { $0.id == item.id }
                        settings.save()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red.opacity(0.95))
                        .background(Circle().fill(Color.black.opacity(0.8)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onHover { hovering in
            hubState.hoveredItemId = hovering ? item.id : nil
        }
    }
    
    // MARK: - New Shortcut End Button
    
    private var newShortcutCardButton: some View {
        Button(action: {
            AuralHapticsManager.shared.play(.tock, haptic: .alignment)
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                hubState.resetForm()
                hubState.isAddingShortcut = true
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                        .frame(width: 58, height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                    
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                }
                
                Text("New")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("No Shortcuts Yet")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text("Add quick actions, apps, web links, or custom system macros.")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.60))
            }
            
            Spacer()
            
            Button("Add First Shortcut") {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                    hubState.resetForm()
                    hubState.isAddingShortcut = true
                }
            }
            .font(.system(size: 10.5, weight: .bold))
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
    
    // MARK: - Add Studio View (Interactive Creator)
    
    private var addStudioView: some View {
        VStack(spacing: 8) {
            // Studio Header
            HStack(spacing: 10) {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        hubState.isAddingShortcut = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .bold))
                        Text("Back")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Category Pills
                HStack(spacing: 4) {
                    ForEach(ShortcutHubCategory.allCases) { cat in
                        Button(action: {
                            withAnimation(.spring(response: 0.20, dampingFraction: 0.78)) {
                                hubState.selectedCategory = cat
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 8.5))
                                Text(cat.rawValue)
                                    .font(.system(size: 9.5, weight: .medium))
                            }
                            .foregroundColor(hubState.selectedCategory == cat ? .white : .white.opacity(0.60))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(
                                hubState.selectedCategory == cat
                                    ? Color.orange.opacity(0.80)
                                    : Color.white.opacity(0.06)
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        hubState.isAddingShortcut = false
                    }
                }) {
                    Text("Done")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Category Studio Content
            Group {
                switch hubState.selectedCategory {
                case .presets:
                    presetsStudio
                case .apps:
                    appsStudio
                case .web:
                    webStudio
                case .custom:
                    customStudio
                case .macro:
                    MacroRecorderView {
                        withAnimation {
                            hubState.isAddingShortcut = false
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Presets Studio
    
    private var presetsStudio: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(presets) { preset in
                    let isAlreadyAdded = settings.shortcuts.contains(where: { $0.name == preset.name })
                    let baseColor = Color(hex: preset.colorHex) ?? Color.blue
                    
                    Button(action: {
                        addShortcutItem(preset)
                    }) {
                        VStack(spacing: 5) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(baseColor.opacity(0.35))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(Color.white.opacity(0.20), lineWidth: 0.7)
                                    )
                                
                                Image(systemName: preset.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Text(preset.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.90))
                                .lineLimit(1)
                            
                            if isAlreadyAdded {
                                Text("Added")
                                    .font(.system(size: 7.5, weight: .bold))
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                            }
                        }
                        .frame(width: 66, height: 84)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Apps Studio
    
    private var appsStudio: some View {
        VStack(spacing: 6) {
            // Search Input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.50))
                TextField("Search installed Mac applications...", text: $hubState.appSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            
            // Apps Horizontal Scroll
            let filtered = hubState.appSearchQuery.isEmpty
                ? appsCache.apps
                : appsCache.apps.filter { $0.name.localizedCaseInsensitiveContains(hubState.appSearchQuery) }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    if filtered.isEmpty {
                        Text(appsCache.apps.isEmpty ? "Scanning applications..." : "No apps match search")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.50))
                            .padding(.horizontal, 16)
                    } else {
                        ForEach(filtered) { app in
                            Button(action: {
                                let item = ShortcutItem(
                                    name: app.name,
                                    icon: "app.fill",
                                    actionType: .launchApp,
                                    actionData: app.id,
                                    colorHex: "#007AFF"
                                )
                                addShortcutItem(item)
                            }) {
                                VStack(spacing: 5) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 44, height: 44)
                                        
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 32, height: 32)
                                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                        } else {
                                            Image(systemName: "app.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    Text(app.name)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.white.opacity(0.90))
                                        .lineLimit(1)
                                        .frame(width: 62)
                                }
                                .frame(width: 66, height: 72)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    // MARK: - Web Studio
    
    private var webStudio: some View {
        VStack(spacing: 8) {
            // Popular 1-Click Web Presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    webPresetButton(name: "Google", url: "https://google.com", icon: "magnifyingglass", color: "#4285F4")
                    webPresetButton(name: "YouTube", url: "https://youtube.com", icon: "play.rectangle.fill", color: "#FF0000")
                    webPresetButton(name: "GitHub", url: "https://github.com", icon: "chevron.left.forwardslash.chevron.right", color: "#24292E")
                    webPresetButton(name: "ChatGPT", url: "https://chatgpt.com", icon: "bubble.left.and.bubble.right.fill", color: "#10A37F")
                    webPresetButton(name: "Reddit", url: "https://reddit.com", icon: "globe", color: "#FF4500")
                    webPresetButton(name: "X (Twitter)", url: "https://x.com", icon: "bubble.right.fill", color: "#000000")
                }
                .padding(.horizontal, 2)
            }
            
            // Custom URL Form
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NAME")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                    TextField("e.g. My Workspace", text: $hubState.webName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .frame(width: 140)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("URL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                    TextField("https://...", text: $hubState.webURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .frame(maxWidth: .infinity)
                
                Button(action: {
                    var finalUrl = hubState.webURL.trimmingCharacters(in: .whitespaces)
                    if !finalUrl.lowercased().hasPrefix("http://") && !finalUrl.lowercased().hasPrefix("https://") {
                        finalUrl = "https://" + finalUrl
                    }
                    let item = ShortcutItem(
                        name: hubState.webName.isEmpty ? "Web Link" : hubState.webName,
                        icon: "globe",
                        actionType: .openURL,
                        actionData: finalUrl,
                        colorHex: "#007AFF"
                    )
                    addShortcutItem(item)
                }) {
                    Text("Add Link")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .disabled(hubState.webName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
    
    private func webPresetButton(name: String, url: String, icon: String, color: String) -> some View {
        Button(action: {
            let item = ShortcutItem(name: name, icon: icon, actionType: .openURL, actionData: url, colorHex: color)
            addShortcutItem(item)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(name)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.09))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Custom Studio
    
    private var customStudio: some View {
        HStack(alignment: .top, spacing: 12) {
            // Live Preview Card
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            (Color(hex: hubState.customColorHex) ?? Color.blue).opacity(0.45)
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.30), lineWidth: 0.8)
                        )
                    
                    Image(systemName: hubState.customIcon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                Text(hubState.customName.isEmpty ? "Preview" : hubState.customName)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .frame(width: 58)
            }
            .frame(width: 60)
            
            // Inputs
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    TextField("Shortcut Name", text: $hubState.customName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    
                    Picker("", selection: $hubState.customActionType) {
                        ForEach(ShortcutActionType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }
                
                TextField("Action Target (Bundle ID, URL, or Action)", text: $hubState.customActionData)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                // Icon Swatches & Color Swatches
                HStack(spacing: 12) {
                    // Icons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(commonSymbols, id: \.self) { symbol in
                                Button(action: {
                                    hubState.customIcon = symbol
                                }) {
                                    Image(systemName: symbol)
                                        .font(.system(size: 11))
                                        .foregroundColor(hubState.customIcon == symbol ? .orange : .white.opacity(0.65))
                                        .frame(width: 22, height: 22)
                                        .background(hubState.customIcon == symbol ? Color.orange.opacity(0.20) : Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: 180)
                    
                    // Colors
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(paletteColors, id: \.self) { hex in
                                Button(action: {
                                    hubState.customColorHex = hex
                                }) {
                                    Circle()
                                        .fill(Color(hex: hex) ?? Color.blue)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: hubState.customColorHex == hex ? 1.5 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button("Save") {
                        let item = ShortcutItem(
                            name: hubState.customName.isEmpty ? "Custom" : hubState.customName,
                            icon: hubState.customIcon,
                            actionType: hubState.customActionType,
                            actionData: hubState.customActionData,
                            colorHex: hubState.customColorHex
                        )
                        addShortcutItem(item)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.mini)
                    .disabled(hubState.customName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addShortcutItem(_ item: ShortcutItem) {
        AuralHapticsManager.shared.play(.completionChime, haptic: .levelChange)
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            settings.shortcuts.append(item)
            settings.save()
            hubState.isAddingShortcut = false
        }
    }
}
