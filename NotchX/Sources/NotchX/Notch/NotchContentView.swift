import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// View model that manages the notch state and coordinates with NotchWindowController.
/// Tuned for ultra-snappy opening (response: 0.26, dampingFraction: 0.82).
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
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

/// Tabs available in the expanded notch matching the screenshot
enum NotchTab: String, CaseIterable {
    case nook = "Nook"
    case audio = "Audio"
    case tray = "Tray"
    
    var iconName: String {
        switch self {
        case .nook: return "sparkles"
        case .audio: return "slider.vertical.3"
        case .tray: return "tray.and.arrow.down.fill"
        }
    }
}

/// State tracking selected tab without using @State macro
class NotchTabState: ObservableObject {
    @Published var selectedTab: NotchTab = .nook
    @Published var isDragTargeted: Bool = false
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
    @ObservedObject private var tabState = NotchTabState()
    @ObservedObject private var activity = ActivityManager.shared
    @ObservedObject private var nowPlaying = NowPlayingManager.shared
    @ObservedObject private var systemHUD = SystemHUDManager.shared
    @ObservedObject private var physics = NotchPhysicsEngine.shared
    @ObservedObject private var micVeil = MicrophoneVeilManager.shared
    
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
        
        let hudW: CGFloat = max(collapsedW, 180) + 84 // ~264-280pt
        let hudH: CGFloat = cameraCutoutHeight + 14   // ~50pt
        
        let currentW = isExp ? expandedW : (isHUD ? hudW : collapsedW)
        let currentH = isExp ? expandedH : (isHUD ? hudH : cameraCutoutHeight)
        
        let notchShape = NotchShape(
            topCornerRadius: isExp ? 10 : (isHUD ? 8 : 6),
            bottomCornerRadius: isExp ? 22 : (isHUD ? 18 : 14)
        )
        
        ZStack(alignment: .top) {
            // === NOTCH CONTAINER (Solid, Crisp, Razor-Sharp Edges, No Translucent Artifacts) ===
            ZStack(alignment: .top) {
                // Layer 1: Base Background with Dynamic Frosted Glass Transparency (Only if user turned on slider)
                if settings.notchTransparency > 0.02 && isExp {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(notchShape)
                }
                
                Color.black.opacity(isExp ? max(1.0 - settings.notchTransparency, 0.12) : 1.0)
                    .clipShape(notchShape)
                
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
                
                // Layer 5: Interactive Notch Content
                VStack(spacing: 0) {
                    if isExp {
                        // === EXPANDED STATE ===
                        // 1. Camera Cutout Spacer: completely clears the physical camera hardware box!
                        Spacer()
                            .frame(height: cameraCutoutHeight + 4)
                        
                        // System Volume / Brightness HUD banner if active
                        if isHUD {
                            SystemHUDView()
                                .padding(.bottom, 6)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // 2. Inner Content Wrapper (Staggered Animation: Notch expands first, text enters later!)
                        VStack(spacing: 0) {
                            headerRow
                                .padding(.horizontal, 16)
                                .padding(.top, 2)
                            
                            tabContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 6)
                                .padding(.bottom, 8)
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
                        
                        if isHUD {
                            // Volume / Brightness Black & White Sparkling Bar HUD!
                            SystemHUDView()
                                .padding(.top, 2)
                                .transition(.scale(scale: 0.94).combined(with: .opacity))
                        } else {
                            // Compact notch hugging the physical camera cutout
                            collapsedNotchContent(width: collapsedW, height: cameraCutoutHeight - topBleed)
                                .transition(.opacity)
                        }
                    }
                }
                
                // Fluid Dynamic Ripple Canvas on impact
                FluidRippleCanvas(intensity: physics.rippleIntensity)
                    .clipShape(notchShape)
                
                // Layer 6: Precision metallic rim stroke
                notchShape
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            }
            .frame(width: currentW, height: currentH, alignment: .top)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHUD)
            .contentShape(notchShape)
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
    
    // MARK: - Header Row (Positioned Under the Camera Box)
    
    private var headerRow: some View {
        HStack(spacing: 8) {
            // Brand Logo
            NXLogoView(height: 12)
                .opacity(0.85)
                .padding(.leading, 2)
            
            // Pill Tab Switcher: Nook | Audio | Tray
            HStack(spacing: 4) {
                ForEach(NotchTab.allCases, id: \.self) { tab in
                    Button(action: {
                        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tabState.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 10, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(tabState.selectedTab == tab ? .white : .white.opacity(0.55))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            tabState.selectedTab == tab
                            ? Color.white.opacity(0.18)
                            : Color.clear
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Quick Utility Actions
            HStack(spacing: 6) {
                // Microphone Privacy Veil (Live Hardware LED & Global Kill Switch)
                MicrophoneVeilView()
                
                // Quick Wallpaper Switcher
                Button(action: cycleWallpaper) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.70))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Cycle Wallpaper (\(settings.currentWallpaper.rawValue))")
                
                // Open Settings
                Button(action: {
                    SettingsWindowController.shared.show()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.70))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("NotchX Settings")
                
                // Close / Collapse Notch
                Button(action: {
                    viewModel.collapseImmediately()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.60))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Collapse Notch")
            }
        }
        .padding(.horizontal, 16)
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
        case .audio:
            AudioCenterView()
        case .tray:
            FileTrayView()
        }
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

/// NSVisualEffectView wrapper providing native frosted glass blur for custom transparency
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
