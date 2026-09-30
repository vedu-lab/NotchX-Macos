import SwiftUI
import AppKit

// MARK: - Glass Material Type

public enum GlassMaterialType: String, CaseIterable, Codable, Identifiable {
    case hudWindow = "Frosted HUD"
    case ultraThin = "Liquid Crystal"
    case popover = "Velvet Matte"
    case underWindow = "Smoked Acrylic"
    case sheet = "Crystal Luminous"
    
    public var id: String { rawValue }
    
    public var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .hudWindow: return .hudWindow
        case .ultraThin: return .fullScreenUI
        case .popover: return .popover
        case .underWindow: return .underWindowBackground
        case .sheet: return .sheet
        }
    }
    
    public var description: String {
        switch self {
        case .hudWindow: return "Deep, rich hardware-grade HUD frosted glass"
        case .ultraThin: return "High-refraction, ultra-translucent liquid glass"
        case .popover: return "Soft velvety matte glass with subtle light absorption"
        case .underWindow: return "Balanced macOS native acrylic frosted surface"
        case .sheet: return "Luminous translucent glass with bright specular glow"
        }
    }
    
    public var iconName: String {
        switch self {
        case .hudWindow: return "sparkles.rectangle.stack"
        case .ultraThin: return "drop.fill"
        case .popover: return "square.stack.3d.down.right"
        case .underWindow: return "macwindow"
        case .sheet: return "sun.max.fill"
        }
    }
}

// MARK: - Glass Tint Type

public enum GlassTintType: String, CaseIterable, Codable, Identifiable {
    case obsidian = "Obsidian Stealth"
    case sapphire = "Electric Sapphire"
    case emerald = "Aurora Emerald"
    case amethyst = "Royal Amethyst"
    case amber = "Sunset Amber"
    case smoke = "Liquid Smoke"
    case rose = "Crimson Quartz"
    case cyan = "Cyber Cyan"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .obsidian: return Color.black
        case .sapphire: return Color(red: 0.12, green: 0.45, blue: 1.0)
        case .emerald: return Color(red: 0.15, green: 0.78, blue: 0.45)
        case .amethyst: return Color(red: 0.65, green: 0.25, blue: 0.95)
        case .amber: return Color(red: 1.0, green: 0.55, blue: 0.15)
        case .smoke: return Color(white: 0.4)
        case .rose: return Color(red: 0.95, green: 0.22, blue: 0.48)
        case .cyan: return Color(red: 0.05, green: 0.82, blue: 0.92)
        }
    }
    
    public var accentGradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.9), color.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Glass Theme Preset

public enum GlassThemePreset: String, CaseIterable, Identifiable {
    case stealthObsidian = "Stealth Obsidian"
    case liquidCrystal = "Liquid Crystal"
    case cyberAurora = "Cyber Aurora"
    case amethystDream = "Royal Amethyst"
    case nordicFrost = "Nordic Frost"
    case solarAmber = "Solar Amber"
    
    public var id: String { rawValue }
    
    public var title: String { rawValue }
    
    public var subtitle: String {
        switch self {
        case .stealthObsidian: return "Solid pitch black hardware look"
        case .liquidCrystal: return "Ultra-translucent liquid glass with sapphire rim"
        case .cyberAurora: return "Luminous emerald tint with vibrant refraction"
        case .amethystDream: return "Luxury deep violet glass with radiant glow"
        case .nordicFrost: return "Crisp arctic acrylic glass with metallic sheen"
        case .solarAmber: return "Warm twilight amber glow with high contrast"
        }
    }
    
    public var iconName: String {
        switch self {
        case .stealthObsidian: return "circle.fill"
        case .liquidCrystal: return "drop.fill"
        case .cyberAurora: return "sparkles"
        case .amethystDream: return "wand.and.stars"
        case .nordicFrost: return "snowflake"
        case .solarAmber: return "flame.fill"
        }
    }
    
    public var config: (transparency: Double, material: GlassMaterialType, tint: GlassTintType, sheen: Double, glow: Bool, topR: CGFloat, bottomR: CGFloat) {
        switch self {
        case .stealthObsidian:
            return (0.0, .hudWindow, .obsidian, 0.4, true, 14, 28)
        case .liquidCrystal:
            return (0.58, .ultraThin, .sapphire, 0.85, true, 16, 30)
        case .cyberAurora:
            return (0.45, .hudWindow, .emerald, 0.90, true, 14, 28)
        case .amethystDream:
            return (0.52, .popover, .amethyst, 0.85, true, 16, 32)
        case .nordicFrost:
            return (0.65, .underWindow, .smoke, 0.75, true, 12, 26)
        case .solarAmber:
            return (0.48, .sheet, .amber, 0.80, true, 14, 28)
        }
    }
}
