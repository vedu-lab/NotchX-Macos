import SwiftUI
import AppKit

struct WallpaperEngine: View {
    let type: WallpaperType
    var isActive: Bool = true
    
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        switch type {
        case .aurora:
            AuroraWallpaper()
        case .gradient:
            GradientWallpaper()
        case .particles:
            ParticleWallpaper()
        case .custom:
            if !settings.customWallpaperPath.isEmpty,
               FileManager.default.fileExists(atPath: settings.customWallpaperPath) {
                let ext = URL(fileURLWithPath: settings.customWallpaperPath).pathExtension.lowercased()
                let imageExtensions = ["jpg", "jpeg", "png", "heic", "webp", "tiff", "bmp", "avif"]
                
                if imageExtensions.contains(ext) {
                    // Custom Photo Wallpaper (JPEG, PNG, HEIC, WebP, TIFF)
                    if let image = NSImage(contentsOfFile: settings.customWallpaperPath) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    } else {
                        AuroraWallpaper()
                    }
                } else {
                    // Custom Video Wallpaper (.mp4, .mov, .gif)
                    VideoWallpaperView(
                        url: URL(fileURLWithPath: settings.customWallpaperPath),
                        isActive: isActive
                    )
                }
            } else {
                AuroraWallpaper()
            }
        }
    }
}
