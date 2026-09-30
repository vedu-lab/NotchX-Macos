import SwiftUI
import AppKit

struct WallpaperEngine: View {
    let type: WallpaperType
    var isActive: Bool = true
    
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var customManager = CustomWallpaperManager.shared
    
    var body: some View {
        switch type {
        case .solidBlack, .solidCharcoal, .solidWhite, .midnightNavy, .slateGray, .forestDark:
            (type.solidColor ?? Color.black)
                .edgesIgnoringSafeArea(.all)
            
        case .particles:
            if isActive {
                ParticleWallpaper()
            } else {
                Color.black
            }
            
        case .custom:
            customWallpaperBody
        }
    }
    
    @ViewBuilder
    private var customWallpaperBody: some View {
        let activeItem = customManager.activeItem
        let path: String = {
            if let item = activeItem {
                return customManager.fileURL(for: item).path
            }
            if !settings.customWallpaperPath.isEmpty,
               FileManager.default.fileExists(atPath: settings.customWallpaperPath) {
                return settings.customWallpaperPath
            }
            return ""
        }()
        
        if !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "heic", "webp", "tiff", "bmp", "avif"]
            let offsetFactor = activeItem?.verticalOffset ?? 0.5
            let scaleFactor = activeItem?.scale ?? 1.0
            
            if imageExtensions.contains(ext) {
                if let image = NSImage(contentsOfFile: path) {
                    GeometryReader { geo in
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(scaleFactor)
                            .offset(y: (CGFloat(offsetFactor) - 0.5) * geo.size.height * 0.8)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else {
                    Color.black
                }
            } else {
                // Video wallpaper
                GeometryReader { geo in
                    VideoWallpaperView(
                        url: URL(fileURLWithPath: path),
                        isActive: isActive
                    )
                    .scaleEffect(scaleFactor)
                    .offset(y: (CGFloat(offsetFactor) - 0.5) * geo.size.height * 0.8)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
            }
        } else {
            Color.black
        }
    }
}
