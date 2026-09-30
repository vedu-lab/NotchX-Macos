// Copyright © 2026 Vedant. All rights reserved.
import SwiftUI
import AppKit

/// Clean, curated Settings categories for NotchX
enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General & Notch"
    case glass = "Liquid Glass & Style"
    case floatingDock = "Floating Dock & Tabs"
    case notificationsGreetings = "Greetings & Notifications"
    case shortcutsAudio = "Shortcuts & Audio"
    case about = "About NotchX"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .general: return "gearshape.2.fill"
        case .glass: return "sparkles"
        case .floatingDock: return "dock.rectangle"
        case .notificationsGreetings: return "bell.badge.fill"
        case .shortcutsAudio: return "command"
        case .about: return "info.circle.fill"
        }
    }
    
    var tintColor: Color {
        switch self {
        case .general: return .blue
        case .glass: return .purple
        case .floatingDock: return .cyan
        case .notificationsGreetings: return .pink
        case .shortcutsAudio: return .orange
        case .about: return .gray
        }
    }
}

/// Observable navigation state avoiding broken @State macro
class ModernSettingsNavState: ObservableObject {
    @Published var selectedCategory: SettingsCategory = .general
    @Published var customGreetingDraft: String = ""
}

/// Remade, ultra-modern macOS 27 Liquid Glass Settings View for NotchX
/// Features:
/// - Cohesive 6-category navigation with glowing icons
/// - Fully responsive inline shortcut builder (no broken modal sheets)
/// - Apple "hello." permanent greeting and floating notification panel controls
/// - Dynamic liquid glass styling with zero outdated system forms
struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var nav = ModernSettingsNavState()
    @ObservedObject private var greetingManager = GreetingManager.shared
    @ObservedObject private var notificationManager = NotificationPanelManager.shared
    
    var body: some View {
        NavigationSplitView {
            // === SIDEBAR ===
            VStack(alignment: .leading, spacing: 6) {
                // Header Brand Title
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.purple)
                    Text("NotchX Preferences")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)
                
                // Categories List
                List(SettingsCategory.allCases, id: \.self, selection: $nav.selectedCategory) { category in
                    sidebarCategoryRow(category: category)
                }
                .listStyle(SidebarListStyle())
                
                Spacer()
                
                // Bottom Status Pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.green.opacity(0.8), radius: 2)
                    Text("Liquid Glass Active")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 225, max: 245)
            .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        } detail: {
            // === DETAIL VIEW ===
            ZStack {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                
                // Liquid Glass Ambient Caustic Sheen
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.08), location: 0.0),
                        .init(color: Color.purple.opacity(0.04), location: 0.25),
                        .init(color: Color.clear, location: 0.65),
                        .init(color: Color.black.opacity(0.20), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 18) {
                        switch nav.selectedCategory {
                        case .general:
                            generalCategoryView
                        case .glass:
                            glassCategoryView
                        case .floatingDock:
                            floatingDockCategoryView
                        case .notificationsGreetings:
                            notificationsGreetingsCategoryView
                        case .shortcutsAudio:
                            shortcutsAudioCategoryView
                        case .about:
                            aboutCategoryView
                        }
                    }
                    .padding(22)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 800, height: 560)
    }
    
    // MARK: - Sidebar Row
    
    private func sidebarCategoryRow(category: SettingsCategory) -> some View {
        NavigationLink(value: category) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(category.tintColor.opacity(0.85))
                        .shadow(color: category.tintColor.opacity(0.35), radius: 2)
                    
                    Image(systemName: category.iconName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)
                
                Text(category.rawValue)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - 1. General & Notch
    
    private var generalCategoryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            modernSectionHeader(
                title: "General & Notch Footprint",
                subtitle: "Configure the hardware notch dimensions, timing, and launch behavior.",
                icon: "gearshape.2.fill",
                tint: .blue
            )
            
            // Expanded Footprint
            modernCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("EXPANDED FOOTPRINT")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.6)
                        
                        Spacer()
                        
                        Button("Reset Defaults") {
                            AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                settings.notchExpandedWidth = 680
                                settings.notchExpandedHeight = 295
                                settings.dockBarSpacing = 4
                            }
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Expanded Width")
                                .font(.body.weight(.medium))
                            Spacer()
                            Text("\(Int(settings.notchExpandedWidth)) px")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.blue)
                        }
                        Slider(value: $settings.notchExpandedWidth, in: 520...800, step: 10)
                            .tint(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Expanded Height")
                                .font(.body.weight(.medium))
                            Spacer()
                            Text("\(Int(settings.notchExpandedHeight)) px")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.blue)
                        }
                        Slider(value: $settings.notchExpandedHeight, in: 180...360, step: 5)
                            .tint(.blue)
                    }
                    
                    Divider().padding(.vertical, 2)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Dock Bar Spacing")
                                .font(.body.weight(.medium))
                            Spacer()
                            Text("\(Int(settings.dockBarSpacing)) px")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.blue)
                        }
                        Slider(value: $settings.dockBarSpacing, in: 0...20, step: 1)
                            .tint(.blue)
                        Text("Gap between the notch bottom and the floating tab dock bar.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Timing & Launch
            modernCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.body.weight(.medium))
                            Text("Automatically start NotchX when your Mac boots.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.launchAtLogin)
                            .labelsHidden()
                            .tint(.blue)
                    }
                    
                    Divider().padding(.vertical, 2)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Auto-Collapse Delay")
                                .font(.body.weight(.medium))
                            Spacer()
                            Text(String(format: "%.2fs", settings.autoCollapseDelay))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.autoCollapseDelay, in: 0.1...1.5, step: 0.05)
                    }
                }
            }
        }
    }
    
    // MARK: - 2. Liquid Glass & Style
    
    private var glassCategoryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            modernSectionHeader(
                title: "Liquid Glass & Appearance",
                subtitle: "macOS 27 iridescent sheen, frosted glass depth, and wallpaper customization.",
                icon: "sparkles",
                tint: .purple
            )
            
            // Liquid Glass Feature
            modernCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13))
                                    .foregroundColor(.purple)
                                Text("Liquid Glass Depth")
                                    .font(.body.weight(.semibold))
                            }
                            Text("macOS 27 system-style glass with spectral caustics and depth shimmer.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.liquidGlassEnabled)
                            .labelsHidden()
                            .tint(.purple)
                    }
                    
                    if settings.liquidGlassEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Liquid Intensity")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(settings.liquidGlassIntensity * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.purple)
                            }
                            Slider(value: $settings.liquidGlassIntensity, in: 0.1...1.0, step: 0.05)
                                .tint(.purple)
                        }
                    }
                }
            }
            
            // Frosted Glass Transparency & Tint
            modernCard {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Frosted Glass Transparency")
                                .font(.body.weight(.medium))
                            Spacer()
                            Text("\(Int(settings.notchTransparency * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.purple)
                        }
                        Slider(value: $settings.notchTransparency, in: 0.0...0.90, step: 0.05)
                            .tint(.purple)
                    }
                    
                    Divider().padding(.vertical, 2)
                    
                    // Glass Color Tint
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GLASS TINT PALETTE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.6)
                        
                        HStack(spacing: 12) {
                            ForEach(GlassTintType.allCases, id: \.self) { tint in
                                Button(action: {
                                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        settings.glassTintType = tint
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(tint.color)
                                            .frame(width: 26, height: 26)
                                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                        
                                        if settings.glassTintType == tint {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(tint.rawValue)
                            }
                        }
                    }
                }
            }
            
            // Wallpapers Gallery
            modernCard {
                WallpaperPickerView()
            }
        }
    }
    
    // MARK: - 3. Floating Dock & Tabs
    
    private var floatingDockCategoryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            modernSectionHeader(
                title: "Floating Dock & Tab Suite",
                subtitle: "Customize the floating tabs bar and toggle the floating notification panel.",
                icon: "dock.rectangle",
                tint: .cyan
            )
            
            // Floating Notification Panel Toggle
            modernCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(.system(size: 13))
                                .foregroundColor(.cyan)
                            Text("Always Show Notification Panel Under Tabs")
                                .font(.body.weight(.semibold))
                        }
                        Text("Keeps the floating notification panel open directly under your floating tabs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.floatingNotificationPanelAlwaysVisible)
                        .labelsHidden()
                        .tint(.cyan)
                }
            }
            
            // Visible Tabs
            modernCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ACTIVE TABS IN DOCK BAR")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(0.6)
                    
                    ForEach(NotchTab.allCases) { tab in
                        let isEnabled = settings.isTabEnabled(tab.rawValue)
                        HStack(spacing: 10) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 12))
                                .foregroundColor(.cyan)
                                .frame(width: 20)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 12.5, weight: .medium))
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { isEnabled },
                                set: { _ in settings.toggleTab(tab.rawValue) }
                            ))
                            .labelsHidden()
                            .tint(.cyan)
                            .disabled(tab == .nook && isEnabled) // Keep at least Home
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
    
    // MARK: - 4. Greetings & Notifications
    
    private var notificationsGreetingsCategoryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            modernSectionHeader(
                title: "Greetings & Notifications",
                subtitle: "Apple \"hello.\" permanent cursive flourish and floating notification panel.",
                icon: "bell.badge.fill",
                tint: .pink
            )
            
            // Apple "hello." Greetings Card
            modernCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                Text("Apple Cursive Greeting in Notch")
                                    .font(.body.weight(.semibold))
                            }
                            Text("Displays the iconic Apple cursive script permanently in the notch header.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.isGreetingAlwaysVisible)
                            .labelsHidden()
                            .tint(.pink)
                    }
                    
                    Divider().padding(.vertical, 2)
                    
                    // Startup Pop-up Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pop Up Fully on NotchX Start")
                                .font(.body.weight(.medium))
                            Text("Pops down the large animated cursive flourish with launch chime when the app starts.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.greetingOnLaunchEnabled)
                            .labelsHidden()
                            .tint(.pink)
                    }
                    
                    Divider().padding(.vertical, 2)
                    
                    // Customizable Greeting Text
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GREETING TEXT")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.6)
                        
                        HStack(spacing: 8) {
                            // Preset buttons
                            ForEach(["hello.", "welcome.", "notchx."], id: \.self) { word in
                                Button(action: {
                                    settings.greetingText = word
                                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                                }) {
                                    Text(word)
                                        .font(.system(size: 11, weight: settings.greetingText == word ? .bold : .medium, design: .rounded))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(settings.greetingText == word ? Color.pink.opacity(0.3) : Color.white.opacity(0.06))
                                        .foregroundColor(settings.greetingText == word ? .white : .white.opacity(0.7))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(settings.greetingText == word ? Color.pink : Color.clear, lineWidth: 0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Custom input field
                            TextField("Custom text...", text: $settings.greetingText)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 160)
                        }
                    }
                    
                    Divider().padding(.vertical, 2)
                    
                    // Action: Test Startup Pop-up
                    Button(action: {
                        greetingManager.triggerLaunchGreeting()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.circle.fill")
                            Text("Preview Startup Pop-up")
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .controlSize(.small)
                }
            }
            
            // Floating Notification Center Card
            modernCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.pink)
                                Text("Floating Notifications")
                                    .font(.body.weight(.semibold))
                            }
                            Text("Real-time notification alerts float just under your floating tabs.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.notificationsEnabled)
                            .labelsHidden()
                            .tint(.pink)
                    }
                    
                    Divider().padding(.vertical, 2)
                    
                    HStack(spacing: 10) {
                        Button(action: {
                            notificationManager.triggerTestNotification()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Simulate Floating Alert")
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        .controlSize(.small)
                        
                        Button(action: {
                            notificationManager.clearAll()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Clear All Notifications")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    // MARK: - 5. Shortcuts & Audio
    
    private var shortcutsAudioCategoryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            modernSectionHeader(
                title: "Shortcuts & Audio",
                subtitle: "Interactive shortcut builder and macOS volume/brightness HUD suppression.",
                icon: "command",
                tint: .orange
            )
            
            // Bug-Free Inline Shortcut Builder Card
            modernCard {
                ShortcutEditorView()
            }
            
            // Audio & Native OSD Suppression
            modernCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Suppress Native macOS HUD")
                                .font(.body.weight(.semibold))
                            Text("Hides the default macOS volume & brightness popups so only the Notch HUD appears.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.suppressNativeOSD)
                            .labelsHidden()
                            .tint(.orange)
                    }
                    
                    Divider().padding(.vertical, 2)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aural Haptics & Sound FX")
                                .font(.body.weight(.medium))
                            Text("Mechanical clicks, chimes, and tactile responses.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.auralHapticsEnabled)
                            .labelsHidden()
                            .tint(.orange)
                    }
                    
                    if settings.auralHapticsEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Sound Volume")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(settings.auralHapticsVolume * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.orange)
                            }
                            Slider(value: $settings.auralHapticsVolume, in: 0.1...1.0, step: 0.05)
                                .tint(.orange)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 6. About NotchX
    
    private var aboutCategoryView: some View {
        VStack(alignment: .leading, spacing: 16) {
            modernSectionHeader(
                title: "About NotchX",
                subtitle: "Version 2.9.7 — Liquid Glass Edition",
                icon: "info.circle.fill",
                tint: .gray
            )
            
            modernCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NotchX")
                                .font(.title2.bold())
                            Text("Luxury MacBook Notch HUD & Desktop Companion")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Version 2.9.7 (Build 2026.09)")
                                .font(.caption2.monospaced())
                                .foregroundColor(.purple)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Copyright © 2026 Vedant. All rights reserved.")
                            .font(.caption.weight(.medium))
                        Text("Proprietary Software. Protected by Hardened Runtime & Anti-Tamper Shield.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Modern UI Helper Components
    
    private func modernSectionHeader(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.85))
                    .shadow(color: tint.opacity(0.4), radius: 4)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 2)
    }
    
    private func modernCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.85
                        )
                )
        )
    }
}
