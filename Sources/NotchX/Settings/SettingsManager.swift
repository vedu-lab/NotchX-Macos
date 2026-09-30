import SwiftUI
import Combine
import Foundation

/// Singleton settings manager that persists all NotchX preferences
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Core Dimensions & Wallpapers
    @Published var currentWallpaper: WallpaperType = .solidBlack { didSet { save() } }
    @Published var shortcuts: [ShortcutItem] = ShortcutItem.defaults { didSet { save() } }
    @Published var launchAtLogin: Bool = false { didSet { save() } }
    @Published var animationSpeed: Double = 1.0 { didSet { save() } }
    @Published var notchExpandedWidth: CGFloat = 680 { didSet { save() } }
    @Published var notchExpandedHeight: CGFloat = 295 { didSet { save() } }
    @Published var customWallpaperPath: String = "" { didSet { save() } }
    
    // Glass & Visual Styling
    @Published var notchTransparency: Double = 0.0 { didSet { save() } } // 0.0 = solid, up to 0.90 = frosted glass
    @Published var glassMaterialType: GlassMaterialType = .hudWindow { didSet { save() } }
    @Published var glassTintType: GlassTintType = .obsidian { didSet { save() } }
    @Published var glassSheenIntensity: Double = 0.65 { didSet { save() } }
    @Published var glassBorderGlow: Bool = true { didSet { save() } }
    // Locked curvature constants (not user-editable)
    var notchTopCornerRadius: CGFloat = 8
    var notchBottomCornerRadius: CGFloat = 16
    
    // Audio & Haptics
    @Published var auralHapticsEnabled: Bool = true { didSet { save() } }
    @Published var auralHapticsVolume: Double = 0.85 { didSet { save() } }
    @Published var suppressNativeOSD: Bool = true {
        didSet {
            save()
            Task { @MainActor in
                if self.suppressNativeOSD {
                    MediaKeyInterceptor.shared.start()
                } else {
                    MediaKeyInterceptor.shared.stop()
                }
            }
        }
    }
    
    // Timing & Behavior
    @Published var autoCollapseDelay: Double = 0.35 { didSet { save() } }
    @Published var hoverExpandDelay: Double = 0.05 { didSet { save() } }
    
    // Floating Dock Bar
    @Published var dockBarSpacing: CGFloat = 4 { didSet { save() } }  // Gap between notch bottom and dock bar
    
    // Liquid Glass (macOS 27 system-style)
    @Published var liquidGlassEnabled: Bool = false { didSet { save() } }
    @Published var liquidGlassIntensity: Double = 0.6 { didSet { save() } }
    
    // Greetings & Floating Notifications
    @Published var greetingText: String = "hello." { didSet { save() } }
    @Published var isGreetingAlwaysVisible: Bool = true { didSet { save() } }
    @Published var greetingOnLaunchEnabled: Bool = true { didSet { save() } }
    @Published var notificationsEnabled: Bool = true { didSet { save() } }
    @Published var floatingNotificationPanelAlwaysVisible: Bool = false { didSet { save() } }
    
    // Tab & Home Customization
    @Published var enabledTabIdentifiers: [String] = ["Home", "Music", "Widgets", "Timers", "Calendar", "Weather", "Shelf", "Clipboard", "Shortcuts"] { didSet { save() } }
    @Published var homeShowMusic: Bool = true { didSet { save() } }
    @Published var homeShowCalendar: Bool = true { didSet { save() } }
    @Published var homeShowShelf: Bool = true { didSet { save() } }
    @Published var homeShowQuickControls: Bool = true { didSet { save() } }
    
    private let defaults = UserDefaults.standard
    
    private init() {
        load()
    }
    
    func applyGlassPreset(_ preset: GlassThemePreset) {
        let conf = preset.config
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            notchTransparency = conf.transparency
            glassMaterialType = conf.material
            glassTintType = conf.tint
            glassSheenIntensity = conf.sheen
            glassBorderGlow = conf.glow
            notchTopCornerRadius = conf.topR
            notchBottomCornerRadius = conf.bottomR
        }
        AuralHapticsManager.shared.play(.sparkleTick, haptic: .levelChange)
    }
    
    func isTabEnabled(_ tabName: String) -> Bool {
        enabledTabIdentifiers.contains(tabName)
    }
    
    func toggleTab(_ tabName: String) {
        if enabledTabIdentifiers.contains(tabName) {
            // Keep at least Home enabled
            if enabledTabIdentifiers.count > 1 || tabName != "Home" {
                enabledTabIdentifiers.removeAll(where: { $0 == tabName })
            }
        } else {
            enabledTabIdentifiers.append(tabName)
        }
    }
    
    func save() {
        if let wallpaperData = try? JSONEncoder().encode(currentWallpaper) {
            defaults.set(wallpaperData, forKey: "notchx.wallpaper")
        }
        if let shortcutsData = try? JSONEncoder().encode(shortcuts) {
            defaults.set(shortcutsData, forKey: "notchx.shortcuts")
        }
        defaults.set(launchAtLogin, forKey: "notchx.launchAtLogin")
        defaults.set(animationSpeed, forKey: "notchx.animationSpeed")
        defaults.set(notchExpandedWidth, forKey: "notchx.expandedWidth")
        defaults.set(notchExpandedHeight, forKey: "notchx.expandedHeight")
        defaults.set(notchTransparency, forKey: "notchx.notchTransparency")
        defaults.set(customWallpaperPath, forKey: "notchx.customWallpaperPath")
        
        defaults.set(glassMaterialType.rawValue, forKey: "notchx.glassMaterialType")
        defaults.set(glassTintType.rawValue, forKey: "notchx.glassTintType")
        defaults.set(glassSheenIntensity, forKey: "notchx.glassSheenIntensity")
        defaults.set(glassBorderGlow, forKey: "notchx.glassBorderGlow")
        // notchTopCornerRadius and notchBottomCornerRadius are locked constants — not saved
        
        defaults.set(auralHapticsEnabled, forKey: "notchx.auralHapticsEnabled")
        defaults.set(auralHapticsVolume, forKey: "notchx.auralHapticsVolume")
        defaults.set(suppressNativeOSD, forKey: "notchx.suppressNativeOSD")
        defaults.set(autoCollapseDelay, forKey: "notchx.autoCollapseDelay")
        defaults.set(hoverExpandDelay, forKey: "notchx.hoverExpandDelay")
        
        defaults.set(dockBarSpacing, forKey: "notchx.dockBarSpacing")
        defaults.set(liquidGlassEnabled, forKey: "notchx.liquidGlassEnabled")
        defaults.set(liquidGlassIntensity, forKey: "notchx.liquidGlassIntensity")
        defaults.set(greetingText, forKey: "notchx.greetingText")
        defaults.set(isGreetingAlwaysVisible, forKey: "notchx.isGreetingAlwaysVisible")
        defaults.set(greetingOnLaunchEnabled, forKey: "notchx.greetingOnLaunchEnabled")
        defaults.set(notificationsEnabled, forKey: "notchx.notificationsEnabled")
        defaults.set(floatingNotificationPanelAlwaysVisible, forKey: "notchx.floatingNotificationPanelAlwaysVisible")
        
        defaults.set(enabledTabIdentifiers, forKey: "notchx.enabledTabs")
        defaults.set(homeShowMusic, forKey: "notchx.homeShowMusic")
        defaults.set(homeShowCalendar, forKey: "notchx.homeShowCalendar")
        defaults.set(homeShowShelf, forKey: "notchx.homeShowShelf")
        defaults.set(homeShowQuickControls, forKey: "notchx.homeShowQuickControls")
    }
    
    func load() {
        if let data = defaults.data(forKey: "notchx.wallpaper"),
           let type = try? JSONDecoder().decode(WallpaperType.self, from: data) {
            currentWallpaper = type
        }
        if let data = defaults.data(forKey: "notchx.shortcuts"),
           let loadedShortcuts = try? JSONDecoder().decode([ShortcutItem].self, from: data) {
            shortcuts = loadedShortcuts
        }
        
        if defaults.object(forKey: "notchx.launchAtLogin") != nil {
            launchAtLogin = defaults.bool(forKey: "notchx.launchAtLogin")
        }
        if defaults.object(forKey: "notchx.animationSpeed") != nil {
            animationSpeed = defaults.double(forKey: "notchx.animationSpeed")
        }
        if defaults.object(forKey: "notchx.expandedWidth") != nil {
            let savedW = CGFloat(defaults.double(forKey: "notchx.expandedWidth"))
            notchExpandedWidth = (savedW < 520 || savedW > 820 || savedW == 580 || savedW == 640 || savedW == 660) ? 680 : savedW
        } else {
            notchExpandedWidth = 680
        }
        if defaults.object(forKey: "notchx.expandedHeight") != nil {
            let savedH = CGFloat(defaults.double(forKey: "notchx.expandedHeight"))
            notchExpandedHeight = (savedH < 180 || savedH > 360 || savedH == 205 || savedH == 190 || savedH == 255 || savedH == 285) ? 295 : savedH
        } else {
            notchExpandedHeight = 295
        }
        if defaults.object(forKey: "notchx.notchTransparency") != nil {
            notchTransparency = defaults.double(forKey: "notchx.notchTransparency")
        }
        if let customPath = defaults.string(forKey: "notchx.customWallpaperPath") {
            customWallpaperPath = customPath
        }
        
        if let matRaw = defaults.string(forKey: "notchx.glassMaterialType"),
           let mat = GlassMaterialType(rawValue: matRaw) {
            glassMaterialType = mat
        }
        if let tintRaw = defaults.string(forKey: "notchx.glassTintType"),
           let t = GlassTintType(rawValue: tintRaw) {
            glassTintType = t
        }
        if defaults.object(forKey: "notchx.glassSheenIntensity") != nil {
            glassSheenIntensity = defaults.double(forKey: "notchx.glassSheenIntensity")
        }
        if defaults.object(forKey: "notchx.glassBorderGlow") != nil {
            glassBorderGlow = defaults.bool(forKey: "notchx.glassBorderGlow")
        }
        // notchTopCornerRadius and notchBottomCornerRadius are locked constants — not loaded
        
        if defaults.object(forKey: "notchx.auralHapticsEnabled") != nil {
            auralHapticsEnabled = defaults.bool(forKey: "notchx.auralHapticsEnabled")
        }
        if defaults.object(forKey: "notchx.auralHapticsVolume") != nil {
            auralHapticsVolume = defaults.double(forKey: "notchx.auralHapticsVolume")
        }
        if defaults.object(forKey: "notchx.suppressNativeOSD") != nil {
            suppressNativeOSD = defaults.bool(forKey: "notchx.suppressNativeOSD")
        }
        if defaults.object(forKey: "notchx.autoCollapseDelay") != nil {
            autoCollapseDelay = defaults.double(forKey: "notchx.autoCollapseDelay")
        }
        if defaults.object(forKey: "notchx.hoverExpandDelay") != nil {
            hoverExpandDelay = defaults.double(forKey: "notchx.hoverExpandDelay")
        }
        if defaults.object(forKey: "notchx.dockBarSpacing") != nil {
            dockBarSpacing = CGFloat(defaults.double(forKey: "notchx.dockBarSpacing"))
        }
        if defaults.object(forKey: "notchx.liquidGlassEnabled") != nil {
            liquidGlassEnabled = defaults.bool(forKey: "notchx.liquidGlassEnabled")
        }
        if defaults.object(forKey: "notchx.liquidGlassIntensity") != nil {
            liquidGlassIntensity = defaults.double(forKey: "notchx.liquidGlassIntensity")
        }
        if let text = defaults.string(forKey: "notchx.greetingText") {
            greetingText = text
        }
        if defaults.object(forKey: "notchx.isGreetingAlwaysVisible") != nil {
            isGreetingAlwaysVisible = defaults.bool(forKey: "notchx.isGreetingAlwaysVisible")
        }
        if defaults.object(forKey: "notchx.greetingOnLaunchEnabled") != nil {
            greetingOnLaunchEnabled = defaults.bool(forKey: "notchx.greetingOnLaunchEnabled")
        }
        if defaults.object(forKey: "notchx.notificationsEnabled") != nil {
            notificationsEnabled = defaults.bool(forKey: "notchx.notificationsEnabled")
        }
        if defaults.object(forKey: "notchx.floatingNotificationPanelAlwaysVisible") != nil {
            floatingNotificationPanelAlwaysVisible = defaults.bool(forKey: "notchx.floatingNotificationPanelAlwaysVisible")
        }
        
        if let tabs = defaults.stringArray(forKey: "notchx.enabledTabs") {
            var merged = tabs.filter { $0 != "Notifications" }
            let allDefaultTabs = ["Home", "Music", "Widgets", "Timers", "Calendar", "Weather", "Shelf", "Clipboard", "Shortcuts"]
            for defaultTab in allDefaultTabs {
                if !merged.contains(defaultTab) && !defaults.bool(forKey: "notchx.disabledTab." + defaultTab) {
                    merged.append(defaultTab)
                }
            }
            enabledTabIdentifiers = merged
        }
        if defaults.object(forKey: "notchx.homeShowMusic") != nil {
            homeShowMusic = defaults.bool(forKey: "notchx.homeShowMusic")
        }
        if defaults.object(forKey: "notchx.homeShowCalendar") != nil {
            homeShowCalendar = defaults.bool(forKey: "notchx.homeShowCalendar")
        }
        if defaults.object(forKey: "notchx.homeShowShelf") != nil {
            homeShowShelf = defaults.bool(forKey: "notchx.homeShowShelf")
        }
        if defaults.object(forKey: "notchx.homeShowQuickControls") != nil {
            homeShowQuickControls = defaults.bool(forKey: "notchx.homeShowQuickControls")
        }
    }
}
