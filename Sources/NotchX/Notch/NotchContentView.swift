import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// View model that manages the notch state and coordinates with NotchWindowController.
/// Tuned for ultra-snappy opening (response: 0.26, dampingFraction: 0.82).
@MainActor
public class NotchViewModel: ObservableObject {
    @Published public var isExpanded = false
    public var onExpansionStateChange: ((Bool) -> Void)?
    
    private var collapseWorkItem: DispatchWorkItem?
    
    public func setHovered(_ hovered: Bool) {
        collapseWorkItem?.cancel()
        
        if hovered {
            if !isExpanded {
                AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                // Immediate window resize followed by rapid spring expansion
                onExpansionStateChange?(true)
                withAnimation(.spring(response: 0.26, dampingFraction: 0.82, blendDuration: 0)) {
                    isExpanded = true
                }
            }
        } else {
            if ShortcutsBranchState.shared.isAddShortcutPresented {
                return
            }
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if ShortcutsBranchState.shared.isAddShortcutPresented {
                    return
                }
                
                AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                // Automatically turn off the shortcuts branch when mouse leaves notch
                ShortcutsBranchState.shared.isBranchExpanded = false
                ShortcutsBranchState.shared.isPinned = false
                
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85, blendDuration: 0)) {
                    self.isExpanded = false
                }
                self.onExpansionStateChange?(false)
            }
            collapseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + SettingsManager.shared.autoCollapseDelay, execute: work)
        }
    }
    
    public func collapseImmediately() {
        collapseWorkItem?.cancel()
        ShortcutsBranchState.shared.isBranchExpanded = false
        ShortcutsBranchState.shared.isAddShortcutPresented = false
        withAnimation(.spring(response: 0.26, dampingFraction: 0.82, blendDuration: 0)) {
            isExpanded = false
        }
        onExpansionStateChange?(false)
    }
    
    public init() {}
}

/// Tabs available in the expanded notch matching the bottom dock bar in media_1790755591920.png
public enum NotchTab: String, CaseIterable, Identifiable {
    case nook = "Home"
    case music = "Music"
    case widgets = "Widgets"
    case timers = "Timers"
    case calendar = "Calendar"
    case weather = "Weather"
    case tray = "Shelf"
    case clipboard = "Clipboard"
    case shortcuts = "Shortcuts"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .nook: return "square.grid.2x2.fill"
        case .music: return "music.note"
        case .widgets: return "chart.xyaxis.line"
        case .timers: return "timer"
        case .calendar: return "calendar"
        case .weather: return "cloud.sun.fill"
        case .tray: return "tray.and.arrow.down.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .shortcuts: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

/// State tracking selected tab without using @State macro
public class NotchTabState: ObservableObject {
    public static let shared = NotchTabState()
    @Published public var selectedTab: NotchTab = .nook
    @Published public var isDragTargeted: Bool = false
    public init() {}
}

/// Main NotchContentView:
/// - Crisp, razor-sharp pitch black edges (no translucent blur/shadow clipping artifacts)
/// - Ultra-snappy opening animation (response: 0.26) where the notch expands FIRST and text dissolves in LATER
/// - Custom video wallpapers sleep/pause when notch collapses to conserve 0% CPU and memory
/// - All tabs, controls, and options cleanly positioned BELOW the physical camera box
/// - Multi-source Home tab (Video calls, Browser media, Music, and Mac Calendar sync)
struct NotchContentView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject private var tabState = NotchTabState.shared
    @ObservedObject private var activity = ActivityManager.shared
    @ObservedObject private var nowPlaying = NowPlayingManager.shared
    @ObservedObject private var systemHUD = SystemHUDManager.shared
    @ObservedObject private var physics = NotchPhysicsEngine.shared
    @ObservedObject private var micVeil = MicrophoneVeilManager.shared
    @ObservedObject private var notificationManager = NotificationPanelManager.shared
    @ObservedObject private var greetingManager = GreetingManager.shared
    
    /// Top bleed matching Atoll's `notchTopScreenBleedAmount` (4pt)
    private let topBleed: CGFloat = 4
    
    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        let isExp = viewModel.isExpanded
        let isHUD = systemHUD.isVisible
        
        let collapsedW = max(NotchDetector.notchWidth(), 180)
        let cameraCutoutHeight = max(NotchDetector.notchHeight(), 32) + topBleed
        let expandedW = settings.notchExpandedWidth
        let expandedH = settings.notchExpandedHeight + topBleed
        
        // HUD floats as a separate pill BELOW the physical notch — wider than the notch
        let hudW: CGFloat = max(collapsedW, 180) + 100  // ~300pt wide pill
        
        let currentW = isExp ? expandedW : collapsedW
        let currentH = isExp ? expandedH : cameraCutoutHeight
        
        let notchShape = NotchShape(
            topCornerRadius: isExp ? settings.notchTopCornerRadius : 6,
            bottomCornerRadius: isExp ? settings.notchBottomCornerRadius : 14
        )
        
        ZStack(alignment: .top) {
            // === NOTCH BODY (Clipped to Notch Shape) ===
            ZStack(alignment: .top) {
                // Layer 1: Base Background with Dynamic Frosted Glass Transparency (Only if user turned on slider)
                if settings.notchTransparency > 0.02 && isExp {
                    VisualEffectView(material: settings.glassMaterialType.nsMaterial, blendingMode: .behindWindow)
                        .clipShape(notchShape)
                }
                
                Color.black.opacity(isExp ? max(1.0 - settings.notchTransparency, 0.12) : 1.0)
                    .clipShape(notchShape)
                
                // Layer 1b: Customizable Liquid Glass Tint (Sapphire, Emerald, Amethyst, Amber, etc.)
                if settings.notchTransparency > 0.04 && isExp && settings.glassTintType != .obsidian {
                    settings.glassTintType.color.opacity(settings.notchTransparency * 0.40)
                        .clipShape(notchShape)
                }
                
                // Layer 2: Animated / Video / Photo Wallpaper
                WallpaperEngine(type: settings.currentWallpaper, isActive: isExp)
                    .drawingGroup(opaque: true)
                    .clipShape(notchShape)
                    .opacity(isExp ? max(1.0 - settings.notchTransparency * 0.45, 0.35) : 0.85)
                
                // Layer 3: Subtle dark glass tint over wallpaper for perfect readability
                Color.black.opacity(isExp ? (0.35 * (1.0 - settings.notchTransparency * 0.5)) : 0.45)
                    .clipShape(notchShape)
                
                // Layer 4: Anti-gap top bleed bar (matches Atoll's anti-gap fill)
                Rectangle()
                    .fill(Color.black)
                    .frame(height: topBleed)
                
                // Layer 5: Interactive Notch Content (tab content only — dock bar is OUTSIDE the clip)
                VStack(spacing: 0) {
                    if isExp {
                        // === EXPANDED STATE ===
                        let isCompact = settings.notchExpandedHeight < 265
                        // 1. Camera Cutout Spacer: completely clears the physical camera hardware box!
                        Spacer()
                            .frame(height: isCompact ? cameraCutoutHeight + 1 : cameraCutoutHeight + 3)
                        
                        // 2. Inner Content Wrapper (Staggered Animation: Notch expands first, text enters later!)
                        let adaptiveTopPadH = max(18, (settings.notchTopCornerRadius + settings.notchBottomCornerRadius) * 0.45)
                        VStack(spacing: 0) {
                            topHeaderRow
                                .padding(.horizontal, adaptiveTopPadH)
                                .padding(.top, isCompact ? 1 : 3)
                            
                            tabContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, isCompact ? 2 : 4)
                                // Bottom padding to make room for the floating dock bar below the notch
                                .padding(.bottom, isCompact ? 4 : 6)
                        }
                        .opacity(isExp ? 1 : 0)
                        .offset(y: isExp ? 0 : -6)
                        .animation(
                            isExp
                                ? .easeOut(duration: 0.20).delay(0.13) // Notch opens first, text enters after 0.13s!
                                : .easeIn(duration: 0.10),             // Text dissolves fast on close
                            value: isExp
                        )
                    } else {
                        // === COLLAPSED STATE ===
                        Spacer()
                            .frame(height: topBleed)
                        
                        // Compact notch hugging the physical camera cutout
                        collapsedNotchContent(width: collapsedW, height: cameraCutoutHeight - topBleed)
                            .transition(.opacity)
                    }
                }
                
                // Fluid Dynamic Ripple Canvas on impact
                FluidRippleCanvas(intensity: physics.rippleIntensity)
                    .clipShape(notchShape)
                
                // Layer 6: Precision specular rim stroke with subtle metallic sheen & customizable liquid glow
                if settings.glassBorderGlow {
                    notchShape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isExp ? (0.16 + 0.32 * settings.glassSheenIntensity) : 0.18),
                                    settings.glassTintType.color.opacity(isExp ? (0.15 + 0.25 * settings.glassSheenIntensity) : 0.08),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: isExp ? 0.85 : 0.5
                        )
                }
                
                // Liquid Glass Layer (macOS 27 system-style iridescent depth sheen)
                if settings.liquidGlassEnabled && isExp {
                    let intensity = settings.liquidGlassIntensity
                    ZStack {
                        // Iridescent top-down spectral sheen
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.18 * intensity), location: 0.0),
                                .init(color: Color.purple.opacity(0.07 * intensity), location: 0.2),
                                .init(color: Color.cyan.opacity(0.06 * intensity), location: 0.45),
                                .init(color: Color.clear, location: 0.65),
                                .init(color: Color.white.opacity(0.04 * intensity), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(notchShape)
                        
                        // Spectral caustic highlight (top inner rim glow)
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.26 * intensity),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.28)
                        )
                        .clipShape(notchShape)
                        .blendMode(.plusLighter)
                    }
                }
            }
            .frame(width: currentW, height: currentH, alignment: .top)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHUD)
            .contentShape(notchShape)
            
            // === FLOATING HUD PILL (Outside Notch Clip — pops BELOW the physical notch) ===
            // Positioned centered and just below the collapsed notch area
            if isHUD && !isExp {
                SystemHUDView()
                    .frame(width: hudW)
                    .offset(y: cameraCutoutHeight + settings.dockBarSpacing)
                    .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHUD)
            }
            
            // Dynamic scale and height for the floating dock bar
            let isCompact = settings.notchExpandedHeight < 265
            let cornerPenalty = max(0, (settings.notchBottomCornerRadius - 16) * 0.012)
            let widthFactor = min(1.0, settings.notchExpandedWidth / 680)
            let dynamicScale = max(0.72, min(1.0, (1.0 - cornerPenalty) * widthFactor))
            let dockH: CGFloat = max(28, (isCompact ? 32 : 36) * dynamicScale)
            
            // === FLOATING DOCK BAR (Outside Notch Clip — pops BELOW expanded notch) ===
            // Only shown when expanded; floats below the bottom edge of the notch shape
            if isExp {
                NotchBottomDockBarView(viewModel: viewModel)
                    .offset(y: expandedH + settings.dockBarSpacing)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.88, anchor: .top).combined(with: .opacity)
                    ))
                    .animation(
                        isExp
                            ? .spring(response: 0.30, dampingFraction: 0.78).delay(0.10)
                            : .easeIn(duration: 0.12),
                        value: isExp
                    )
            }
            
            // === FLOATING NOTIFICATION PANEL (Just Under Floating Dock) ===
            let isDockPanelOpen = notificationManager.isDockPanelVisible || settings.floatingNotificationPanelAlwaysVisible
            if isExp && isDockPanelOpen {
                FloatingNotificationDockPanelView(viewModel: viewModel)
                    .offset(y: expandedH + settings.dockBarSpacing + dockH + 6)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isDockPanelOpen)
            }
            
            // === FLOATING NOTIFICATION BANNER (Outside Notch Clip — alerts below notch/dock) ===
            if notificationManager.isBannerVisible {
                FloatingNotificationBannerView(viewModel: viewModel)
                    .offset(y: (isExp ? (expandedH + settings.dockBarSpacing + dockH + (isDockPanelOpen ? 195 : 6)) : cameraCutoutHeight) + settings.dockBarSpacing)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: notificationManager.isBannerVisible)
            }
            
            // === FLOATING LAUNCH / INTERACTIVE GREETING (Outside Notch Clip) ===
            if greetingManager.isGreetingActive && !notificationManager.isBannerVisible {
                LaunchGreetingOverlay()
                    .offset(y: (isExp ? (expandedH + settings.dockBarSpacing + dockH + 6) : cameraCutoutHeight) + settings.dockBarSpacing)
                    .animation(.spring(response: 0.32, dampingFraction: 0.80), value: greetingManager.isGreetingActive)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { hovering in
            viewModel.setHovered(hovering)
        }
        .onDrop(
            of: [UTType.fileURL, UTType.item, UTType.image, UTType.data],
            isTargeted: Binding(
                get: { tabState.isDragTargeted },
                set: { targeted in
                    tabState.isDragTargeted = targeted
                    if targeted {
                        // Immediately shift directly to Tray tab on drag!
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                            tabState.selectedTab = .tray
                        }
                        viewModel.setHovered(true)
                    } else {
                        viewModel.setHovered(false)
                    }
                }
            )
        ) { providers in
            physics.triggerDropImpact()
            AuralHapticsManager.shared.play(.whoosh, haptic: .levelChange)
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                tabState.selectedTab = .tray
            }
            FileTrayManager.shared.addProviders(providers)
            viewModel.setHovered(true)
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotchDidReceiveDrag"))) { _ in
            physics.triggerDropImpact()
            AuralHapticsManager.shared.play(.whoosh, haptic: .levelChange)
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                tabState.selectedTab = .tray
            }
            viewModel.setHovered(true)
        }
    }

    
    // MARK: - Top Header Row (Positioned Under the Camera Cutout matching reference image)
    
    private var dynamicGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
    private var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    private var topHeaderRow: some View {
        let isCompact = settings.notchExpandedHeight < 265
        return HStack(alignment: .center, spacing: 10) {
            // Left: Greeting & Current Date/Workspace + Apple Hello Script
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(dynamicGreeting)
                        .font(.system(size: isCompact ? 13 : 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 5) {
                        Text(formattedDateString)
                            .font(.system(size: isCompact ? 8.5 : 9.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.60))
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.35))
                        
                        HStack(spacing: 3) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 7.5))
                                .foregroundColor(.blue.opacity(0.9))
                            Text("Personal Workspace")
                                .font(.system(size: isCompact ? 8 : 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }
                }
                
                // Apple Cursive "hello." Interactive Flourish Badge (Always visible when enabled)
                if settings.isGreetingAlwaysVisible {
                    HelloScriptView(compact: true)
                }
            }
            
            Spacer(minLength: 8)
            
            // Right: Live Status Badges & Quick Tools
            HStack(spacing: 6) {
                // Live Status Pill ("• Active")
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                        .shadow(color: Color.green.opacity(0.8), radius: 2)
                    
                    Text("Active")
                        .font(.system(size: isCompact ? 8.5 : 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.80))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                
                // Microphone Privacy Veil (Live Hardware LED & Kill Switch)
                MicrophoneVeilView()
                
                // Quick Wallpaper Switcher
                Button(action: cycleWallpaper) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Cycle Wallpaper (\(settings.currentWallpaper.rawValue))")
            }
        }
    }
    
    private func cycleWallpaper() {
        let all = WallpaperType.allCases
        if let idx = all.firstIndex(of: settings.currentWallpaper) {
            let next = all[(idx + 1) % all.count]
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                settings.currentWallpaper = next
            }
        }
    }
    
    // MARK: - Collapsed Notch Content
    
    private func collapsedNotchContent(width: CGFloat, height: CGFloat) -> some View {
        HStack {
            // Left wing indicator
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 4, height: 4)
                .padding(.leading, 12)
            
            Spacer()
            
            // Microphone Privacy Veil (Hardware LED / Kill Switch Indicator)
            MicrophoneVeilView(compact: true)
                .padding(.trailing, 4)
            
            // Right wing indicator: reflects current background activity
            if activity.isCallActive {
                // Video Call Active (Pulsing Green Dot)
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 12)
            } else if nowPlaying.isPlaying {
                // Music/Media Playing (Equalizer)
                MiniMusicWave()
                    .padding(.trailing, 12)
            } else if case .browserMedia = activity.currentSource {
                // Browser Playing (Tiny Play Symbol)
                Image(systemName: "play.fill")
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.trailing, 12)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 4, height: 4)
                    .padding(.trailing, 12)
            }
        }
        .frame(width: width, height: height)
    }
    
    // MARK: - Tab Content Router
    
    @ViewBuilder
    private var tabContent: some View {
        switch tabState.selectedTab {
        case .nook:
            HomeView()
        case .music:
            FullMusicTabView()
        case .widgets:
            WidgetsTabView()
        case .timers:
            TimersTabView()
        case .calendar:
            FullCalendarTabView()
        case .weather:
            FullWeatherTabView()
        case .tray:
            FileTrayView()
        case .clipboard:
            ClipboardTabView()
        case .shortcuts:
            ShortcutsFullTabView()
        }
    }
}

// MARK: - Notch Bottom Dock Bar (Floating Pill matching media_1790755591920.png)

struct NotchBottomDockBarView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var tabState = NotchTabState.shared
    @ObservedObject private var notificationManager = NotificationPanelManager.shared
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        let isCompact = settings.notchExpandedHeight < 265
        let cornerPenalty = max(0, (settings.notchBottomCornerRadius - 16) * 0.012)
        let widthFactor = min(1.0, settings.notchExpandedWidth / 680)
        let dynamicScale = max(0.72, min(1.0, (1.0 - cornerPenalty) * widthFactor))
        
        let dockBtnSize: CGFloat = max(24, (isCompact ? 26 : 30) * dynamicScale)
        let iconSize: CGFloat = max(10, (isCompact ? 11 : 12.5) * dynamicScale)
        let dockH: CGFloat = max(28, (isCompact ? 32 : 36) * dynamicScale)
        let dockSpacing: CGFloat = max(3, (isCompact ? 4 : 5.5) * dynamicScale)
        let dockPadH: CGFloat = max(6, (isCompact ? 7 : 10) * dynamicScale)
        
        HStack(spacing: dockSpacing) {
            // Left Pill: Tab Icons
            HStack(spacing: dockSpacing) {
                ForEach(NotchTab.allCases.filter { settings.isTabEnabled($0.rawValue) }) { tab in
                    let isSelected = tabState.selectedTab == tab
                    Button(action: {
                        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            tabState.selectedTab = tab
                        }
                    }) {
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.24))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                                    )
                                    .shadow(color: Color.white.opacity(0.15), radius: 3)
                            }
                            
                            Image(systemName: tab.iconName)
                                .font(.system(size: iconSize, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.60))
                        }
                        .frame(width: dockBtnSize, height: dockBtnSize)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(tab.rawValue)
                }
            }
            
            // Vertical micro-divider
            Rectangle()
                .fill(Color.white.opacity(0.20))
                .frame(width: 0.75, height: dockBtnSize * 0.6)
                .padding(.horizontal, 2)
            
            // Settings Button
            Button(action: {
                SettingsWindowController.shared.showSettings()
                AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: dockBtnSize, height: dockBtnSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("NotchX Settings")
            
            // Notification Panel Toggle Button (Down-facing arrow under floating dock)
            Button(action: {
                notificationManager.toggleDockPanel()
            }) {
                ZStack {
                    if notificationManager.isDockPanelVisible {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.purple.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.purple.opacity(0.55), lineWidth: 0.8)
                            )
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: iconSize * 0.9, weight: .bold))
                        .foregroundColor(notificationManager.isDockPanelVisible ? .white : .white.opacity(0.70))
                        .rotationEffect(.degrees(notificationManager.isDockPanelVisible ? 180 : 0))
                        .animation(.spring(response: 0.26, dampingFraction: 0.8), value: notificationManager.isDockPanelVisible)
                    
                    // Unread badge indicator dot on down arrow
                    if notificationManager.unreadCount > 0 && !notificationManager.isDockPanelVisible {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 5.5, height: 5.5)
                            .offset(x: 6.5, y: -6.5)
                            .shadow(color: Color.purple.opacity(0.9), radius: 2)
                    }
                }
                .frame(width: dockBtnSize, height: dockBtnSize)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(notificationManager.isDockPanelVisible ? "Hide Notification Panel" : "Show Notification Panel")
        }
        .padding(.horizontal, dockPadH)
        .frame(height: dockH)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.68))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.24), Color.white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.75
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 8, y: 3)
        )
    }
}

/// Mini 3-bar animated equalizer shown on collapsed notch when music is playing
struct MiniMusicWave: View {
    @ObservedObject private var nowPlaying = NowPlayingManager.shared
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: 4 + CGFloat(sin(t * 8) * 3 + 3))
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: 4 + CGFloat(cos(t * 10) * 4 + 4))
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2, height: 4 + CGFloat(sin(t * 12 + 1) * 3 + 3))
            }
            .frame(height: 14)
        }
    }
}
