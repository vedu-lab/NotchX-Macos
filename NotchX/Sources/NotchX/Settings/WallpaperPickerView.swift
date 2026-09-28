import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Card-based wallpaper selector with live animated previews, custom photo & video file picker,
/// and custom notch transparency slider.
struct WallpaperPickerView: View {
    @ObservedObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select an animated wallpaper style for your notch:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(WallpaperType.allCases) { type in
                        WallpaperCard(
                            type: type,
                            isSelected: settings.currentWallpaper == type
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                settings.currentWallpaper = type
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Custom Photo or Video Selector Section
            if settings.currentWallpaper == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Photo or Video Wallpaper")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if !settings.customWallpaperPath.isEmpty {
                                let ext = URL(fileURLWithPath: settings.customWallpaperPath).pathExtension.lowercased()
                                let isImg = ["jpg", "jpeg", "png", "heic", "webp", "tiff", "bmp", "avif"].contains(ext)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: isImg ? "photo.fill" : "video.fill")
                                        .foregroundColor(isImg ? .purple : .blue)
                                    Text(isImg ? "Photo Wallpaper" : "Video Wallpaper")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                
                                Text(URL(fileURLWithPath: settings.customWallpaperPath).lastPathComponent)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                
                                Text(settings.customWallpaperPath)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("No photo or video selected yet")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Choose Photo or Video...") {
                            chooseCustomWallpaper()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    Text("Supported: JPG, PNG, HEIC, WEBP, GIF, MP4, MOV. Video wallpapers automatically sleep when closed to consume 0% CPU & memory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Notch Transparency Setting Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundColor(.blue)
                    Text("Notch Background Transparency")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(settings.notchTransparency * 100))%")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.blue)
                }
                
                Slider(value: $settings.notchTransparency, in: 0.0...0.80, step: 0.05)
                
                Text("Adjust how see-through the notch background is when expanded. Higher transparency creates a modern frosted glass blur blending with your desktop.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Description of active wallpaper
            VStack(alignment: .leading, spacing: 4) {
                Text(settings.currentWallpaper.rawValue)
                    .font(.headline)
                Text(settings.currentWallpaper.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            Spacer()
        }
    }
    
    private func chooseCustomWallpaper() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .png,
            .jpeg,
            .image,
            .heic,
            .webP,
            .gif,
            .mpeg4Movie,
            .quickTimeMovie,
            .movie
        ]
        panel.prompt = "Set as Wallpaper"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.customWallpaperPath = url.path
            settings.currentWallpaper = .custom
        }
    }
}

struct WallpaperCard: View {
    let type: WallpaperType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    // Live animated wallpaper preview
                    WallpaperEngine(type: type, isActive: true)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(width: 135, height: 90)
                    
                    // Mini notch contour preview inside
                    NotchShape(topCornerRadius: 4, bottomCornerRadius: 8)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        .frame(width: 75, height: 16)
                        .position(x: 67, y: 8)
                    
                    // Selected checkmark badge
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.blue)
                                    .background(Circle().fill(Color.white))
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.blue : Color.white.opacity(0.15), lineWidth: isSelected ? 2.5 : 1)
                )
                .shadow(color: isSelected ? Color.blue.opacity(0.35) : Color.black.opacity(0.12), radius: isSelected ? 5 : 2, y: 2)
                
                Text(type.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
