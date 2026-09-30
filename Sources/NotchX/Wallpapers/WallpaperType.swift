import Foundation
import SwiftUI

public enum WallpaperType: String, CaseIterable, Codable, Identifiable {
    case solidBlack = "OLED Pitch Black"
    case solidCharcoal = "Deep Charcoal"
    case solidWhite = "Frost Silver"
    case midnightNavy = "Midnight Navy"
    case slateGray = "Apple Slate"
    case forestDark = "Forest Night"
    case particles = "Star Dust"
    case custom = "Custom Wallpaper"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .solidBlack: return "circle.fill"
        case .solidCharcoal: return "circle.lefthalf.filled"
        case .solidWhite: return "circle"
        case .midnightNavy: return "moon.stars.fill"
        case .slateGray: return "square.fill"
        case .forestDark: return "leaf.fill"
        case .particles: return "sparkles"
        case .custom: return "photo.on.rectangle.angled"
        }
    }
    
    public var description: String {
        switch self {
        case .solidBlack: return "Pitch black matching the MacBook physical camera notch with zero distractions."
        case .solidCharcoal: return "Deep space gray slate with understated elegance."
        case .solidWhite: return "Clean frosted silver white with premium high-contrast typography."
        case .midnightNavy: return "Rich midnight navy blue tailored for macOS dark mode."
        case .slateGray: return "Subtle Apple graphite slate matching native dark themes."
        case .forestDark: return "Deep evergreen obsidian for an organic, focused workspace."
        case .particles: return "Subtle, weightless monochrome particles drifting softly."
        case .custom: return "Custom photo or video wallpaper with interactive crop & position alignment."
        }
    }
    
    public var solidColor: Color? {
        switch self {
        case .solidBlack: return Color.black
        case .solidCharcoal: return Color(red: 0.11, green: 0.11, blue: 0.12)
        case .solidWhite: return Color(red: 0.94, green: 0.94, blue: 0.96)
        case .midnightNavy: return Color(red: 0.04, green: 0.07, blue: 0.16)
        case .slateGray: return Color(red: 0.17, green: 0.22, blue: 0.28)
        case .forestDark: return Color(red: 0.05, green: 0.15, blue: 0.09)
        default: return nil
        }
    }
}
