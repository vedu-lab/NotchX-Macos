import Foundation

enum WallpaperType: String, CaseIterable, Codable, Identifiable {
    case aurora = "Aurora Borealis"
    case gradient = "Flowing Gradient"
    case particles = "Particle Field"
    case custom = "Custom Wallpaper"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .aurora: return "waveform"
        case .gradient: return "paintpalette"
        case .particles: return "sparkles"
        case .custom: return "photo.on.rectangle.angled"
        }
    }
    
    var description: String {
        switch self {
        case .aurora: return "Mesmerizing aurora borealis lights pulsing with celestial greens and violets."
        case .gradient: return "Smoothly flowing rich color gradients cycling through deep hues."
        case .particles: return "Weightless glowing particles floating upward with real-time physics."
        case .custom: return "Custom photo (.jpg, .png, .heic) or video (.mp4, .mov) wallpaper that sleeps when closed."
        }
    }
}
