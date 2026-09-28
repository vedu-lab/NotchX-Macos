import SwiftUI
import Combine
import Foundation

/// Singleton settings manager that persists all NotchX preferences
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var currentWallpaper: WallpaperType = .aurora { didSet { save() } }
    @Published var shortcuts: [ShortcutItem] = ShortcutItem.defaults { didSet { save() } }
    @Published var launchAtLogin: Bool = false { didSet { save() } }
    @Published var animationSpeed: Double = 1.0 { didSet { save() } }
    @Published var notchExpandedWidth: CGFloat = 580 { didSet { save() } }
    @Published var notchExpandedHeight: CGFloat = 205 { didSet { save() } }
    @Published var notchTransparency: Double = 0.0 { didSet { save() } } // 0.0 = solid, up to 0.80 = frosted glass
    @Published var customWallpaperPath: String = "" { didSet { save() } }
    @Published var auralHapticsEnabled: Bool = true { didSet { save() } }
    @Published var auralHapticsVolume: Double = 0.85 { didSet { save() } }
    
    private let defaults = UserDefaults.standard
    
    private init() {
        load()
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
        defaults.set(auralHapticsEnabled, forKey: "notchx.auralHapticsEnabled")
        defaults.set(auralHapticsVolume, forKey: "notchx.auralHapticsVolume")
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
            notchExpandedWidth = (savedW < 500 || savedW > 700) ? 580 : savedW
        } else {
            notchExpandedWidth = 580
        }
        if defaults.object(forKey: "notchx.expandedHeight") != nil {
            let savedH = CGFloat(defaults.double(forKey: "notchx.expandedHeight"))
            notchExpandedHeight = (savedH < 150 || savedH > 260 || savedH == 190) ? 205 : savedH
        } else {
            notchExpandedHeight = 205
        }
        if defaults.object(forKey: "notchx.notchTransparency") != nil {
            notchTransparency = defaults.double(forKey: "notchx.notchTransparency")
        }
        if let customPath = defaults.string(forKey: "notchx.customWallpaperPath") {
            customWallpaperPath = customPath
        }
        if defaults.object(forKey: "notchx.auralHapticsEnabled") != nil {
            auralHapticsEnabled = defaults.bool(forKey: "notchx.auralHapticsEnabled")
        }
        if defaults.object(forKey: "notchx.auralHapticsVolume") != nil {
            auralHapticsVolume = defaults.double(forKey: "notchx.auralHapticsVolume")
        }
    }
}
