import SwiftUI
import AppKit

/// Categorized settings tabs matching Atoll's organization
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case appearance
    case soundHaptics
    case media
    case fileTray
    case shortcuts
    case about
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .soundHaptics: return "Sound & Haptics"
        case .media: return "Media"
        case .fileTray: return "File Shelf"
        case .shortcuts: return "Shortcuts"
        case .about: return "About"
        }
    }
    
    var groupTitle: String {
        switch self {
        case .general, .appearance, .soundHaptics: return "Core"
        case .media, .fileTray, .shortcuts: return "Features"
        case .about: return "Info"
        }
    }
    
    var systemImage: String {
        switch self {
        case .general: return "gear"
        case .appearance: return "paintpalette"
        case .soundHaptics: return "speaker.wave.3.fill"
        case .media: return "play.laptopcomputer"
        case .fileTray: return "tray.and.arrow.down"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
    
    var tint: Color {
        switch self {
        case .general: return .blue
        case .appearance: return .purple
        case .soundHaptics: return .pink
        case .media: return .green
        case .fileTray: return .brown
        case .shortcuts: return .orange
        case .about: return .gray
        }
    }
}

/// Navigation state avoiding @State macro
class SettingsNavigationState: ObservableObject {
    @Published var selectedTab: SettingsTab = .general
    @Published var searchText: String = ""
}

/// Atoll-inspired Settings View with a native macOS sidebar layout,
/// Apple System Settings-style colored icon badges, and organized grouped forms.
struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var navState = SettingsNavigationState()
    
    var body: some View {
        NavigationSplitView {
            // === SIDEBAR ===
            List(selection: $navState.selectedTab) {
                // Core Group
                Section("Core") {
                    ForEach([SettingsTab.general, .appearance, .soundHaptics]) { tab in
                        sidebarItem(for: tab)
                    }
                }
                
                // Features Group
                Section("Features") {
                    ForEach([SettingsTab.media, .fileTray, .shortcuts]) { tab in
                        sidebarItem(for: tab)
                    }
                }
                
                // Info Group
                Section("Info") {
                    sidebarItem(for: .about)
                }
            }
            .listStyle(SidebarListStyle())
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 230)
        } detail: {
            // === DETAIL VIEW ===
            detailView(for: navState.selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 720, height: 500)
    }
    
    // MARK: - Sidebar Item
    
    @ViewBuilder
    private func sidebarItem(for tab: SettingsTab) -> some View {
        NavigationLink(value: tab) {
            HStack(spacing: 10) {
                // Colored gradient badge matching Atoll's sidebar icon
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [tab.tint.opacity(1.0), tab.tint.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6)
                        )
                        .shadow(color: tab.tint.opacity(0.3), radius: 2, y: 1)
                    
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Detail Router
    
    @ViewBuilder
    private func detailView(for tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            generalDetail
        case .appearance:
            appearanceDetail
        case .soundHaptics:
            soundHapticsDetail
        case .media:
            mediaDetail
        case .fileTray:
            fileTrayDetail
        case .shortcuts:
            shortcutsDetail
        case .about:
            aboutDetail
        }
    }
    
    // MARK: - General Tab
    
    private var generalDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "General",
                subtitle: "Configure startup behavior and notch overlay dimensions.",
                icon: "gear",
                tint: .blue
            )
            
            Form {
                Section("System") {
                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                }
                
                Section("Notch Dimensions & Glass Transparency") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Expanded Width")
                            Spacer()
                            Text("\(Int(settings.notchExpandedWidth)) px")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.notchExpandedWidth, in: 500...680, step: 10)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Expanded Height")
                            Spacer()
                            Text("\(Int(settings.notchExpandedHeight)) px")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.notchExpandedHeight, in: 140...250, step: 5)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Notch Transparency")
                            Spacer()
                            Text("\(Int(settings.notchTransparency * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.notchTransparency, in: 0.0...0.80, step: 0.05)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Animation Speed")
                            Spacer()
                            Text("\(settings.animationSpeed, specifier: "%.1f")x")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.animationSpeed, in: 0.5...2.5, step: 0.1)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding()
    }
    
    // MARK: - Appearance Tab
    
    private var appearanceDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "Appearance",
                subtitle: "Choose the dynamic animated wallpaper displayed inside the notch.",
                icon: "paintpalette",
                tint: .purple
            )
            
            WallpaperPickerView()
        }
        .padding()
    }
    
    // MARK: - Sound & Haptics Tab
    
    private var soundHapticsDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "Sound & Haptics",
                subtitle: "Zero-latency in-memory synthesized audio cues & Force Touch haptics.",
                icon: "speaker.wave.3.fill",
                tint: .pink
            )
            
            Form {
                Section("Master Configuration") {
                    Toggle("Enable Aural Haptics", isOn: $settings.auralHapticsEnabled)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Acoustic Volume")
                            Spacer()
                            Text("\(Int(settings.auralHapticsVolume * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.auralHapticsVolume, in: 0.0...1.0, step: 0.05)
                            .disabled(!settings.auralHapticsEnabled)
                    }
                }
                
                Section("Interactive Acoustic Auditioning") {
                    auditionRow(
                        title: "Organic Tock",
                        desc: "Window snapping, tab switching, and notch open/close",
                        icon: "rectangle.compress.vertical",
                        sound: .tock,
                        haptic: .alignment
                    )
                    
                    auditionRow(
                        title: "Vault Whoosh",
                        desc: "Dragging and dropping items into the file shelf",
                        icon: "tray.and.arrow.down.fill",
                        sound: .whoosh,
                        haptic: .levelChange
                    )
                    
                    auditionRow(
                        title: "Mechanical Switch",
                        desc: "Microphone hardware kill switch & app volume mute",
                        icon: "switch.2",
                        sound: .mechanicalClick,
                        haptic: .generic
                    )
                    
                    auditionRow(
                        title: "Crystalline Micro-Tick",
                        desc: "Sparkling brightness & volume HUD level shifts",
                        icon: "sparkles",
                        sound: .sparkleTick,
                        haptic: .levelChange
                    )
                    
                    auditionRow(
                        title: "Harmonic Chord Chime",
                        desc: "Macro recording completion & persistent shortcut saved",
                        icon: "bell.badge.fill",
                        sound: .completionChime,
                        haptic: .levelChange
                    )
                }
                
                Section("Hardware Architecture") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "cpu")
                                .foregroundColor(.blue)
                            Text("Real-Time Synthesis (PCM 44.1kHz 16-bit)")
                                .font(.caption.bold())
                        }
                        Text("All audio transients are algorithmically calculated in RAM at launch. No external audio files, 0ms I/O latency.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Divider().padding(.vertical, 2)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(.pink)
                            Text("Synchronized Force Touch Haptics")
                                .font(.caption.bold())
                        }
                        Text("Paired directly with macOS NSHapticFeedbackManager to deliver simultaneous acoustic and physical tactile impulses.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
        }
        .padding()
    }
    
    private func auditionRow(title: String, desc: String, icon: String, sound: AuralSound, haptic: HapticFeedbackPattern) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.pink)
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Test") {
                AuralHapticsManager.shared.play(sound, haptic: haptic)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.pink)
            .disabled(!settings.auralHapticsEnabled)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Media Tab
    
    private var mediaDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "Media & Playback",
                subtitle: "Control background music playback directly from the notch.",
                icon: "play.laptopcomputer",
                tint: .green
            )
            
            Form {
                Section("Apple Music Integration") {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.pink)
                        VStack(alignment: .leading) {
                            Text("Apple Music Support")
                                .font(.headline)
                            Text("Automatically detects playing track, artist name, and provides controls.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Active")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                Section("Features") {
                    Text("• Collapsed notch shows a mini 3-bar animated equalizer when music is playing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• Expanded notch provides Previous, Play/Pause, and Next track controls")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .padding()
    }
    
    // MARK: - File Shelf Tab
    
    private var fileTrayDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "File Shelf",
                subtitle: "Temporarily hold files in your notch while switching applications.",
                icon: "tray.and.arrow.down",
                tint: .brown
            )
            
            Form {
                Section("Overview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drag files from Finder into the notch to hold them temporarily.")
                            .font(.body)
                        Text("Switch to any window, hover over the notch, and drag the files back out into Slack, Mail, or any other app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Capacity") {
                    HStack {
                        Text("Maximum Files")
                        Spacer()
                        Text("10 items")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding()
    }
    
    // MARK: - Shortcuts Tab
    
    private var shortcutsDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "Shortcuts",
                subtitle: "Configure quick-launch applications, URLs, and system actions.",
                icon: "keyboard",
                tint: .orange
            )
            
            ShortcutEditorView()
        }
        .padding()
    }
    
    // MARK: - About Tab
    
    private var aboutDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: "About NotchX",
                subtitle: "Version 1.3.0",
                icon: "info.circle",
                tint: .gray
            )
            
            Form {
                Section("Product Information") {
                    HStack(spacing: 16) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NotchX")
                                .font(.title2.bold())
                            Text("Premium MacBook Notch Overlay with Dynamic Wallpapers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                Section("License & Copyright") {
                    Text("Copyright © 2026 Vedant. All rights reserved.")
                        .font(.caption)
                    Text("Proprietary Software. Protected by Copyright & Anti-Tamper Shield.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .padding()
    }
    
    // MARK: - Section Header Component
    
    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(1.0), tint.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.7)
                    )
                    .shadow(color: tint.opacity(0.35), radius: 3, y: 1)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}
