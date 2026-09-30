import SwiftUI
import AppKit

/// Observable state managing the hover expansion and shortcut creation panel
class ShortcutsBranchState: ObservableObject {
    static let shared = ShortcutsBranchState()
    
    @Published var isBranchExpanded: Bool = false
    @Published var isPinned: Bool = false
    @Published var isAddShortcutPresented: Bool = false
    @Published var selectedAddCategory: AddCategory = .presets
    @Published var customURLName: String = ""
    @Published var customURLString: String = "https://"
    
    enum AddCategory: String, CaseIterable {
        case presets = "Quick Actions"
        case apps = "Applications"
        case web = "Web URL"
        case macro = "Record Actions"
    }
    
    private var collapseTimer: DispatchWorkItem?
    
    func scheduleCollapse(delay: Double = 0.35) {
        if isAddShortcutPresented { return }
        collapseTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isAddShortcutPresented else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                self.isBranchExpanded = false
                self.isPinned = false
            }
        }
        collapseTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    
    func cancelCollapseTimer() {
        collapseTimer?.cancel()
    }
    
    func showAddShortcut() {
        cancelCollapseTimer()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            isAddShortcutPresented = true
        }
    }
    
    func dismissAddShortcut() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            isAddShortcutPresented = false
        }
    }
}

/// Cache of installed applications loaded asynchronously to maintain 60fps
class AppsCache: ObservableObject {
    static let shared = AppsCache()
    @Published var apps: [InstalledApp] = []
    
    init() {
        loadApps()
    }
    
    func loadApps() {
        Task.detached(priority: .userInitiated) {
            let loaded = await MainActor.run {
                AppLauncher.installedApps()
            }
            await MainActor.run {
                self.apps = loaded.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
            }
        }
    }
}

/// Helper hover state class avoiding broken @State macro
class ItemHoverState: ObservableObject {
    @Published var isHovered: Bool = false
    init() {}
}

/// Unified Nook Home View matching the requested HUD:
/// - Left: Music Player (Album art with badge, Track title, Album, Artist, Playback controls)
/// - Center: Calendar (Large Month, 7-day horizontal weekday strip with today in blue, upcoming event preview)
/// - Right: Circular Shortcuts action button (replaces Mirror)
/// - Hover Branch: Sleek horizontal row of circular shortcut icons, scrollable with end '+' button
/// - Add Panel: Spacious, crystal-clear, perfectly aligned shortcut creation studio
/// - Background Activity: Replaces with Video Call HUD if a call is active
struct HomeView: View {
    @ObservedObject private var activity = ActivityManager.shared
    @ObservedObject private var branchState = ShortcutsBranchState.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        Group {
            if activity.isCallActive {
                // Live Video Call Controls (FaceTime / Zoom / Meet)
                videoCallView(appName: activity.callAppName)
            } else if branchState.isAddShortcutPresented {
                // Full Spacious, Perfectly Aligned Add Shortcut Studio
                AddShortcutPanel(branchState: branchState)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        )
                    )
            } else {
                let isCompact = settings.notchExpandedHeight < 265
                VStack(spacing: isCompact ? 5 : 7) {
                    // 1. Top Row: Music Row (Album Art, Song Title, Music Tag, Equalizer, Scrubber, Controls)
                    if settings.homeShowMusic {
                        ScreenshotMusicBarView(isCompact: isCompact)
                    }
                    
                    // 2. Middle Row: Two Action Cards (File Shelf & Calendar Strip)
                    if settings.homeShowShelf || settings.homeShowCalendar {
                        HStack(spacing: isCompact ? 6 : 8) {
                            if settings.homeShowShelf {
                                FileShelfQuickCard(isCompact: isCompact)
                            }
                            if settings.homeShowCalendar {
                                CalendarStripQuickCard(isCompact: isCompact)
                            }
                        }
                    }
                    
                    // 3. Bottom Row: Status & Quick Controls (Timer, Battery, Volume Slider, Settings)
                    if settings.homeShowQuickControls {
                        ScreenshotBottomControlsRowView(isCompact: isCompact)
                    }
                }
                .padding(.horizontal, isCompact ? 12 : 14)
                .padding(.vertical, isCompact ? 3 : 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Video Call View (FaceTime / Zoom / Meet)
    
    private func videoCallView(appName: String) -> some View {
        HStack(spacing: 14) {
            // Live Call Status Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.5), lineWidth: 3)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(appName) Call")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Call in Progress")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Call Action Buttons
            HStack(spacing: 12) {
                // Mic Mute Toggle
                Button(action: {
                    activity.toggleMicrophoneMute()
                }) {
                    VStack(spacing: 3) {
                        Image(systemName: activity.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(activity.isMicMuted ? Color.red.opacity(0.8) : Color.white.opacity(0.18))
                            .clipShape(Circle())
                        Text(activity.isMicMuted ? "Muted" : "Mute")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                
                // Camera Toggle
                Button(action: {
                    activity.toggleCamera()
                }) {
                    VStack(spacing: 3) {
                        Image(systemName: activity.isCameraOff ? "video.slash.fill" : "video.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(activity.isCameraOff ? Color.orange.opacity(0.8) : Color.white.opacity(0.18))
                            .clipShape(Circle())
                        Text(activity.isCameraOff ? "Cam Off" : "Camera")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                
                // End Call Button
                Button(action: {
                    activity.endCurrentCall()
                }) {
                    VStack(spacing: 3) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.red)
                            .clipShape(Circle())
                        Text("End Call")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.red.opacity(0.9))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Shortcuts Action Button (Replaces Mirror Button)

/// Circular 50x50 Quick Action "Shortcuts" button matching the notch HUD style
struct ShortcutsActionButton: View {
    @ObservedObject var branchState: ShortcutsBranchState
    @ObservedObject private var hover = ItemHoverState()
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                branchState.isBranchExpanded.toggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(
                        branchState.isBranchExpanded
                            ? Color.blue.opacity(0.35)
                            : (hover.isHovered ? Color.white.opacity(0.20) : Color.white.opacity(0.12))
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                branchState.isBranchExpanded
                                    ? Color(red: 0.35, green: 0.7, blue: 1.0).opacity(0.8)
                                    : Color.white.opacity(0.15),
                                lineWidth: branchState.isBranchExpanded ? 1.2 : 0.5
                            )
                    )
                
                VStack(spacing: 2) {
                    Image(systemName: "square.stack.3d.down.right.fill")
                        .font(.system(size: 15))
                        .foregroundColor(
                            branchState.isBranchExpanded
                                ? Color(red: 0.45, green: 0.8, blue: 1.0)
                                : Color.white.opacity(0.88)
                        )
                    
                    Text("Shortcuts")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.80))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            hover.isHovered = isHovered
            if isHovered {
                branchState.cancelCollapseTimer()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    branchState.isBranchExpanded = true
                }
            } else {
                branchState.scheduleCollapse()
            }
        }
        .help("Shortcuts (Hover to reveal branch, click to pin open)")
    }
}

// MARK: - Shortcuts Branch View

/// Horizontal branch displaying all saved shortcuts as circles, scrollable, with an end '+' button
struct ShortcutsBranchView: View {
    @ObservedObject var branchState: ShortcutsBranchState
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Branch connector indicator
            HStack(spacing: 4) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.75, blue: 1.0))
                
                Text("SHORTCUTS")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.leading, 8)
            
            // Vertical micro-divider
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 0.5, height: 26)
            
            // Horizontal ScrollView of circular shortcuts + Plus button
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(settings.shortcuts) { shortcut in
                        CircularShortcutItemView(shortcut: shortcut)
                    }
                    
                    // Circular '+' button at the end of the branch
                    AddShortcutCircleButton(branchState: branchState)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.40))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                )
        )
        .padding(.horizontal, 16)
        .onHover { isHovered in
            if isHovered {
                branchState.cancelCollapseTimer()
            } else {
                branchState.scheduleCollapse()
            }
        }
    }
}

// MARK: - Circular Shortcut Item View

/// Individual circular shortcut icon button with enhanced label width and alignment
struct CircularShortcutItemView: View {
    let shortcut: ShortcutItem
    @ObservedObject private var hover = ItemHoverState()
    
    var body: some View {
        Button(action: {
            ShortcutExecutor.execute(shortcut)
        }) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    (Color(hex: shortcut.colorHex) ?? Color.blue).opacity(hover.isHovered ? 0.95 : 0.80),
                                    (Color(hex: shortcut.colorHex) ?? Color.blue).opacity(hover.isHovered ? 0.70 : 0.50)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.white.opacity(hover.isHovered ? 0.6 : 0.25),
                                    lineWidth: hover.isHovered ? 1.0 : 0.6
                                )
                        )
                        .shadow(
                            color: (Color(hex: shortcut.colorHex) ?? Color.blue).opacity(hover.isHovered ? 0.5 : 0.15),
                            radius: hover.isHovered ? 5 : 2,
                            y: 1
                        )
                    
                    Image(systemName: shortcut.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(hover.isHovered ? 1.10 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.65), value: hover.isHovered)
                
                Text(shortcut.name)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.white.opacity(hover.isHovered ? 0.95 : 0.65))
                    .lineLimit(1)
                    .frame(maxWidth: 54)
            }
            .frame(width: 54)
        }
        .buttonStyle(TrayButtonStyle())
        .onHover { hovering in
            hover.isHovered = hovering
            if hovering {
                ShortcutsBranchState.shared.cancelCollapseTimer()
            }
        }
        .contextMenu {
            Button(role: .destructive, action: {
                SettingsManager.shared.shortcuts.removeAll { $0.id == shortcut.id }
            }) {
                Label("Delete Shortcut", systemImage: "trash")
            }
        }
        .help("\(shortcut.name) (\(shortcut.actionType.rawValue))")
    }
}

// MARK: - Add Shortcut Circular Button

/// Circular '+' button at the end of the scrollable row of circles
struct AddShortcutCircleButton: View {
    @ObservedObject var branchState: ShortcutsBranchState
    @ObservedObject private var hover = ItemHoverState()
    
    var body: some View {
        Button(action: {
            branchState.showAddShortcut()
        }) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(hover.isHovered ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    hover.isHovered ? Color.white.opacity(0.6) : Color.white.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 0.9, dash: [3, 2.5])
                                )
                        )
                    
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white.opacity(hover.isHovered ? 1.0 : 0.75))
                }
                .scaleEffect(hover.isHovered ? 1.10 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.65), value: hover.isHovered)
                
                Text("Add")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.white.opacity(hover.isHovered ? 0.95 : 0.65))
                    .frame(maxWidth: 54)
            }
            .frame(width: 54)
        }
        .buttonStyle(TrayButtonStyle())
        .onHover { hovering in
            hover.isHovered = hovering
            if hovering {
                ShortcutsBranchState.shared.cancelCollapseTimer()
            }
        }
        .help("Add New Shortcut")
    }
}

// MARK: - Spacious, Perfectly Aligned Add Shortcut Studio

/// Full-profile shortcut creation studio: perfectly aligned cards, clear typography, and zero clipping
struct AddShortcutPanel: View {
    @ObservedObject var branchState: ShortcutsBranchState
    @ObservedObject private var appsCache = AppsCache.shared
    
    let presets: [ShortcutItem] = [
        ShortcutItem(name: "Notes", icon: "note.text", actionType: .launchApp, actionData: "com.apple.Notes", colorHex: "#FF9500"),
        ShortcutItem(name: "Messages", icon: "message.fill", actionType: .launchApp, actionData: "com.apple.MobileSMS", colorHex: "#34C759"),
        ShortcutItem(name: "Mail", icon: "envelope.fill", actionType: .launchApp, actionData: "com.apple.mail", colorHex: "#007AFF"),
        ShortcutItem(name: "Calculator", icon: "plus.forwardslash.minus", actionType: .launchApp, actionData: "com.apple.calculator", colorHex: "#FF9500"),
        ShortcutItem(name: "Terminal", icon: "terminal", actionType: .launchApp, actionData: "com.apple.Terminal", colorHex: "#2C2C2E"),
        ShortcutItem(name: "VS Code", icon: "chevron.left.forwardslash.chevron.right", actionType: .launchApp, actionData: "com.microsoft.VSCode", colorHex: "#007ACC"),
        ShortcutItem(name: "Spotify", icon: "music.note.list", actionType: .launchApp, actionData: "com.spotify.client", colorHex: "#1DB954"),
        ShortcutItem(name: "Screenshot", icon: "camera.viewfinder", actionType: .systemAction, actionData: "Screenshot", colorHex: "#34C759"),
        ShortcutItem(name: "Lock Screen", icon: "lock.fill", actionType: .systemAction, actionData: "Lock Screen", colorHex: "#FF3B30"),
        ShortcutItem(name: "Dark Mode", icon: "moon.circle.fill", actionType: .systemAction, actionData: "Toggle Dark Mode", colorHex: "#5856D6"),
        ShortcutItem(name: "Do Not Disturb", icon: "moon.zzz.fill", actionType: .systemAction, actionData: "Do Not Disturb", colorHex: "#5856D6"),
        ShortcutItem(name: "Empty Trash", icon: "trash.fill", actionType: .systemAction, actionData: "Empty Trash", colorHex: "#8E8E93"),
        ShortcutItem(name: "Sleep Display", icon: "display.sleep", actionType: .systemAction, actionData: "Sleep Display", colorHex: "#3A3A3C")
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            // Header: Title + Category Segmented Pill + Done Button
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.blue)
                    
                    Text("Add Shortcut")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Category Pills
                HStack(spacing: 4) {
                    ForEach(ShortcutsBranchState.AddCategory.allCases, id: \.self) { cat in
                        Button(action: {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                                branchState.selectedAddCategory = cat
                            }
                        }) {
                            Text(cat.rawValue)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(branchState.selectedAddCategory == cat ? .white : .white.opacity(0.60))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3.5)
                                .background(
                                    branchState.selectedAddCategory == cat
                                        ? Color.blue.opacity(0.7)
                                        : Color.white.opacity(0.08)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Done Button
                Button(action: {
                    branchState.dismissAddShortcut()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("Done")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            // Body Content Area (Spacious & Vertically Aligned)
            Group {
                switch branchState.selectedAddCategory {
                case .presets:
                    presetsView
                case .apps:
                    appsView
                case .web:
                    webView
                case .macro:
                    MacroRecorderView {
                        branchState.dismissAddShortcut()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 2)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Presets View
    
    private var presetsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets) { preset in
                    presetCard(item: preset)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    private func presetCard(item: ShortcutItem) -> some View {
        Button(action: {
            addShortcut(item)
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (Color(hex: item.colorHex) ?? Color.blue).opacity(0.95),
                                    (Color(hex: item.colorHex) ?? Color.blue).opacity(0.65)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 36
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                        .shadow(color: (Color(hex: item.colorHex) ?? Color.blue).opacity(0.3), radius: 3, y: 1)
                    
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(item.name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 64, height: 26, alignment: .top)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .frame(width: 72, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(TrayButtonStyle())
    }
    
    // MARK: - Apps View
    
    private var appsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if appsCache.apps.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading installed applications...")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(width: 200, height: 80)
                } else {
                    ForEach(appsCache.apps) { app in
                        appCard(app: app)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
    
    private func appCard(app: InstalledApp) -> some View {
        Button(action: {
            let item = ShortcutItem(
                name: app.name,
                icon: "app.fill",
                actionType: .launchApp,
                actionData: app.id,
                colorHex: "#007AFF"
            )
            addShortcut(item)
        }) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                        )
                    
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                }
                
                Text(app.name)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 64, height: 26, alignment: .top)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .frame(width: 72, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(TrayButtonStyle())
    }
    
    // MARK: - Web Link View
    
    private var webView: some View {
        VStack(spacing: 8) {
            // Row 1: 1-Click Popular Web Presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    webPresetCapsule(name: "Google", url: "https://google.com", icon: "magnifyingglass", color: "#4285F4")
                    webPresetCapsule(name: "YouTube", url: "https://youtube.com", icon: "play.rectangle.fill", color: "#FF0000")
                    webPresetCapsule(name: "GitHub", url: "https://github.com", icon: "chevron.left.forwardslash.chevron.right", color: "#24292E")
                    webPresetCapsule(name: "ChatGPT", url: "https://chatgpt.com", icon: "bubble.left.and.bubble.right.fill", color: "#10A37F")
                    webPresetCapsule(name: "Reddit", url: "https://reddit.com", icon: "globe", color: "#FF4500")
                    webPresetCapsule(name: "X (Twitter)", url: "https://x.com", icon: "bubble.right.fill", color: "#000000")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 1)
            }
            
            // Row 2: Custom URL Form (Aligned & High Contrast)
            HStack(spacing: 8) {
                // Name Field
                VStack(alignment: .leading, spacing: 2) {
                    Text("NAME")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                    
                    TextField("e.g. My Dashboard", text: $branchState.customURLName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
                        )
                }
                .frame(width: 170)
                
                // URL Field
                VStack(alignment: .leading, spacing: 2) {
                    Text("WEBSITE URL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                    
                    TextField("https://...", text: $branchState.customURLString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10.5))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.6)
                        )
                }
                .frame(width: 230)
                
                // Add Button
                Button(action: addCustomURL) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add URL")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .disabled(branchState.customURLName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func webPresetCapsule(name: String, url: String, icon: String, color: String) -> some View {
        Button(action: {
            let item = ShortcutItem(name: name, icon: icon, actionType: .openURL, actionData: url, colorHex: color)
            addShortcut(item)
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(name)
                    .font(.system(size: 9.5, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
            )
        }
        .buttonStyle(TrayButtonStyle())
    }
    
    private func addCustomURL() {
        let name = branchState.customURLName.trimmingCharacters(in: .whitespaces)
        var urlStr = branchState.customURLString.trimmingCharacters(in: .whitespaces)
        if !urlStr.lowercased().hasPrefix("http://") && !urlStr.lowercased().hasPrefix("https://") {
            urlStr = "https://" + urlStr
        }
        
        let item = ShortcutItem(
            name: name.isEmpty ? "Web Link" : name,
            icon: "globe",
            actionType: .openURL,
            actionData: urlStr,
            colorHex: "#007AFF"
        )
        addShortcut(item)
        branchState.customURLName = ""
        branchState.customURLString = "https://"
    }
    
    private func addShortcut(_ item: ShortcutItem) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            SettingsManager.shared.shortcuts.append(item)
            branchState.dismissAddShortcut()
        }
    }
}

// MARK: - Screenshot Music Scrubber State

class MusicScrubberState: ObservableObject {
    static let shared = MusicScrubberState()
    @Published var progress: Double = 0.22
    @Published var currentTime: String = "00:58"
    @Published var durationTime: String = "06:54"
    @Published var isPlaying: Bool = true
    
    private var timer: Timer?
    private var secondsElapsed: Int = 58
    private let totalSeconds: Int = 414 // 6:54
    
    init() {
        startTimer()
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, NowPlayingManager.shared.isPlaying else { return }
            self.secondsElapsed = (self.secondsElapsed + 1) % self.totalSeconds
            self.progress = Double(self.secondsElapsed) / Double(self.totalSeconds)
            let mins = self.secondsElapsed / 60
            let secs = self.secondsElapsed % 60
            self.currentTime = String(format: "%02d:%02d", mins, secs)
        }
    }
    
    func togglePlaying() {
        isPlaying.toggle()
    }
}

// MARK: - Screenshot Music Bar View (1:1 Reference Match)

struct ScreenshotMusicBarView: View {
    var isCompact: Bool = false
    @ObservedObject private var nowPlaying = NowPlayingManager.shared
    @ObservedObject private var scrubberState = MusicScrubberState.shared
    
    var body: some View {
        HStack(spacing: isCompact ? 9 : 11) {
            albumArtView
            
            // Integrated Center Column: Track + Artist + Scrubber Bar
            VStack(alignment: .leading, spacing: isCompact ? 2 : 3) {
                // Line 1: Track title + Music / Spotify pill tag
                HStack(spacing: 5) {
                    Text(nowPlaying.isMediaDetected ? nowPlaying.trackName : "Logic Miles and Running")
                        .font(.system(size: isCompact ? 11.5 : 12.5, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(nowPlaying.isMediaDetected && !nowPlaying.activePlayerName.isEmpty ? nowPlaying.activePlayerName : "Music")
                        .font(.system(size: isCompact ? 7.5 : 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    
                    Spacer(minLength: 0)
                }
                
                // Line 2: Mini Equalizer bars + Artist Name
                HStack(spacing: 5) {
                    MiniEqualizerBars(isPlaying: nowPlaying.isMediaDetected ? nowPlaying.isPlaying : scrubberState.isPlaying)
                    
                    Text(nowPlaying.isMediaDetected ? nowPlaying.artistName : "Logic")
                        .font(.system(size: isCompact ? 9.5 : 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                }
                
                // Line 3: Timestamp & Scrubber Row
                scrubberView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Playback controls on the right
            playbackControlsView
        }
        .padding(.horizontal, isCompact ? 10 : 12)
        .padding(.vertical, isCompact ? 5 : 7)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 11 : 13, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: isCompact ? 11 : 13, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }
    
    @ViewBuilder
    private var albumArtView: some View {
        let artSize: CGFloat = isCompact ? 30 : 34
        ZStack {
            if let art = nowPlaying.albumArtwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.25, blue: 0.45), Color(red: 0.35, green: 0.15, blue: 0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .font(.system(size: isCompact ? 12 : 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .frame(width: artSize, height: artSize)
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 7 : 8, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1.5)
    }
    
    @ViewBuilder
    private var scrubberView: some View {
        HStack(spacing: 5) {
            Text(scrubberState.currentTime)
                .font(.system(size: isCompact ? 8.5 : 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 2.5)
                    
                    Capsule()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: max(0, min(geo.size.width, geo.size.width * scrubberState.progress)), height: 2.5)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .shadow(color: .black.opacity(0.4), radius: 1.5)
                        .offset(x: max(0, min(geo.size.width - 6, geo.size.width * scrubberState.progress - 3)))
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let pct = max(0.0, min(1.0, val.location.x / geo.size.width))
                            scrubberState.progress = pct
                        }
                )
            }
            .frame(height: isCompact ? 8 : 10)
            
            Text(scrubberState.durationTime)
                .font(.system(size: isCompact ? 8.5 : 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
        }
    }
    
    @ViewBuilder
    private var playbackControlsView: some View {
        let isTrackPlaying = (nowPlaying.isMediaDetected ? nowPlaying.isPlaying : scrubberState.isPlaying)
        let btnSize: CGFloat = isCompact ? 22 : 25
        HStack(spacing: isCompact ? 9 : 11) {
            Button(action: {
                nowPlaying.previousTrack()
                AuralHapticsManager.shared.play(.tock, haptic: .alignment)
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: isCompact ? 9.5 : 11))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            
            Button(action: {
                nowPlaying.playPause()
                scrubberState.togglePlaying()
                AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: btnSize, height: btnSize)
                        .shadow(color: .black.opacity(0.35), radius: 2.5, x: 0, y: 1)
                    
                    Image(systemName: isTrackPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isCompact ? 9 : 10, weight: .bold))
                        .foregroundColor(.black)
                        .offset(x: isTrackPlaying ? 0 : 0.6)
                }
            }
            .buttonStyle(.plain)
            
            Button(action: {
                nowPlaying.nextTrack()
                AuralHapticsManager.shared.play(.tock, haptic: .alignment)
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: isCompact ? 9.5 : 11))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Mini Equalizer Bars

struct MiniEqualizerBars: View {
    let isPlaying: Bool
    
    var body: some View {
        if isPlaying {
            TimelineView(.animation(minimumInterval: 0.15)) { context in
                let t = context.date.timeIntervalSinceReferenceDate * 4.0
                HStack(alignment: .bottom, spacing: 1.8) {
                    barView(t: t, phase: 0.0, minH: 3, maxH: 9)
                    barView(t: t, phase: 0.3, minH: 5, maxH: 12)
                    barView(t: t, phase: 0.6, minH: 2, maxH: 8)
                }
                .frame(height: 12)
            }
        } else {
            HStack(alignment: .bottom, spacing: 1.8) {
                Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 4)
                Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 6)
                Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 3)
            }
            .frame(height: 12)
        }
    }
    
    private func barView(t: Double, phase: Double, minH: CGFloat, maxH: CGFloat) -> some View {
        let heightFactor = (sin(t + phase * 6.28) + 1.0) / 2.0
        let currentH = minH + (maxH - minH) * CGFloat(heightFactor)
        return Capsule()
            .fill(Color.white.opacity(0.85))
            .frame(width: 2, height: currentH)
    }
}

// MARK: - File Shelf Quick Card

struct FileShelfQuickCard: View {
    var isCompact: Bool = false
    @ObservedObject private var hover = ItemHoverState()
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                NotchTabState.shared.selectedTab = .tray
            }
            AuralHapticsManager.shared.play(.whoosh, haptic: .generic)
        }) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.blue.opacity(0.22))
                        .frame(width: isCompact ? 22 : 25, height: isCompact ? 22 : 25)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: isCompact ? 11 : 12.5, weight: .semibold))
                        .foregroundColor(.blue.opacity(0.95))
                }
                
                VStack(alignment: .leading, spacing: 1.5) {
                    Text("File Shelf")
                        .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Drop files onto NotchX")
                        .font(.system(size: isCompact ? 8.5 : 9.5))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.40))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, isCompact ? 5 : 7)
            .frame(maxWidth: .infinity, minHeight: isCompact ? 42 : 48, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(hover.isHovered ? 0.12 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.white.opacity(hover.isHovered ? 0.22 : 0.12), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hover.isHovered = $0 }
    }
}

// MARK: - Calendar Strip Quick Card (Restored Interactive 21-Day Strip)

struct CalendarStripQuickCard: View {
    var isCompact: Bool = false
    @ObservedObject private var hover = ItemHoverState()
    
    var body: some View {
        Button(action: {
            if let url = URL(string: "calshow:") {
                NSWorkspace.shared.open(url)
            }
            AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
        }) {
            CalendarStripView(isCompact: isCompact)
                .padding(.horizontal, 9)
                .padding(.vertical, isCompact ? 4 : 6)
                .frame(maxWidth: .infinity, minHeight: isCompact ? 42 : 48, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(hover.isHovered ? 0.12 : 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(hover.isHovered ? 0.22 : 0.12), lineWidth: 0.6)
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hover.isHovered = $0 }
    }
}

// MARK: - Screenshot Bottom Controls Row View

struct ScreenshotBottomControlsRowView: View {
    var isCompact: Bool = false
    @ObservedObject private var timerMgr = TimerManager.shared
    @ObservedObject private var batteryMgr = BatteryMonitor.shared
    @ObservedObject private var audioMgr = AudioRoutingManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    @ObservedObject private var timerHover = ItemHoverState()
    @ObservedObject private var batteryHover = ItemHoverState()
    @ObservedObject private var volumeHover = ItemHoverState()
    
    var body: some View {
        // Dynamic scaling: shrinks function keys when corner radius is high or width is narrow
        let cornerPenalty = max(0, (settings.notchBottomCornerRadius - 16) * 0.012)
        let widthFactor = min(1.0, settings.notchExpandedWidth / 680)
        let dynamicScale = max(0.72, min(1.0, (1.0 - cornerPenalty) * widthFactor))
        
        let capsuleH: CGFloat = max(19, (isCompact ? 22 : 25) * dynamicScale)
        let textFont: Font = .system(size: max(7.5, (isCompact ? 9 : 9.5) * dynamicScale), weight: .medium)
        let iconSize: CGFloat = max(8, (isCompact ? 9 : 10) * dynamicScale)
        let innerPadH: CGFloat = max(5, (isCompact ? 6 : 8) * dynamicScale)
        let spacing: CGFloat = max(4, (isCompact ? 5 : 7) * dynamicScale)
        let sliderMinW: CGFloat = max(28, 42 * dynamicScale)
        let sliderMaxW: CGFloat = max(44, 72 * dynamicScale)
        
        // Inset from curved corners so nothing ever clips or protrudes
        let adaptiveCornerInset = max(16, (settings.notchTopCornerRadius + settings.notchBottomCornerRadius) * 0.70 + 4)
        
        HStack(spacing: spacing) {
            // 1. Timer Capsule
            HStack(spacing: 4 * dynamicScale) {
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(Color.orange.opacity(0.95))
                
                Text(timerMgr.isRunning ? timerMgr.formattedTime : "Timer 25m")
                    .font(textFont)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Button(action: {
                    timerMgr.toggle()
                    AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
                }) {
                    Image(systemName: timerMgr.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: max(5.5, 6.5 * dynamicScale), weight: .bold))
                        .foregroundColor(.white)
                        .padding(2.5 * dynamicScale)
                        .background(Color.white.opacity(0.20))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, innerPadH)
            .frame(height: capsuleH)
            .background(
                Capsule()
                    .fill(Color.white.opacity(timerHover.isHovered ? 0.12 : 0.08))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
                    )
            )
            .onHover { timerHover.isHovered = $0 }
            
            // 2. Battery Capsule
            HStack(spacing: 4 * dynamicScale) {
                Image(systemName: batteryMgr.iconName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(batteryMgr.level > 20 ? Color.green.opacity(0.9) : Color.red.opacity(0.9))
                
                Text("Bat \(batteryMgr.level)%")
                    .font(textFont)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, innerPadH)
            .frame(height: capsuleH)
            .background(
                Capsule()
                    .fill(Color.white.opacity(batteryHover.isHovered ? 0.12 : 0.08))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
                    )
            )
            .onHover { batteryHover.isHovered = $0 }
            
            // 3. Volume Slider Capsule
            HStack(spacing: 4 * dynamicScale) {
                Image(systemName: audioMgr.masterVolume < 0.05 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: max(2, 3 * dynamicScale))
                        
                        Capsule()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(audioMgr.masterVolume))), height: max(2, 3 * dynamicScale))
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: max(5, 6.5 * dynamicScale), height: max(5, 6.5 * dynamicScale))
                            .shadow(color: .black.opacity(0.35), radius: 1.5)
                            .offset(x: max(0, min(geo.size.width - 6, geo.size.width * CGFloat(audioMgr.masterVolume) - 3)))
                    }
                    .frame(height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                let pct = max(0.0, min(1.0, Double(val.location.x / geo.size.width)))
                                audioMgr.setMasterSystemVolume(pct)
                            }
                    )
                }
                .frame(height: 12)
                .frame(minWidth: sliderMinW, maxWidth: sliderMaxW)
                
                Text("\(Int(audioMgr.masterVolume * 100))%")
                    .font(.system(size: max(7.5, (isCompact ? 8.5 : 9) * dynamicScale), weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, innerPadH)
            .frame(height: capsuleH)
            .background(
                Capsule()
                    .fill(Color.white.opacity(volumeHover.isHovered ? 0.12 : 0.08))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
                    )
            )
            .onHover { volumeHover.isHovered = $0 }
            
        }
        .padding(.horizontal, adaptiveCornerInset)
    }
}


