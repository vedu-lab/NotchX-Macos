import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Clean helper state avoiding broken @State macro in Swift toolchain
class WallpaperPickerHoverState: ObservableObject {
    @Published var hoveredItemID: UUID? = nil
}

/// State for adjusting the visible framing slice of custom photos/videos
class WallpaperFramingState: ObservableObject {
    @Published var framingItem: CustomWallpaperItem? = nil
    @Published var verticalOffset: Double = 0.5
    @Published var scale: Double = 1.0
}

/// Card-based wallpaper selector with solid luxury colors,
/// persistent Saved Custom Wallpapers gallery, and interactive visible slice framing.
struct WallpaperPickerView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var customManager = CustomWallpaperManager.shared
    @ObservedObject private var hoverState = WallpaperPickerHoverState()
    @ObservedObject private var framingState = WallpaperFramingState()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Interactive Framing / Crop Overlay (If Active)
            if let item = framingState.framingItem {
                framingEditorView(item: item)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Section 1: Inbuilt Solid & Minimal Wallpapers
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SOLID & MINIMAL STYLES")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(0.6)
                    
                    Spacer()
                    
                    Text("Pure colors & star dust")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach([
                            WallpaperType.solidBlack,
                            .solidCharcoal,
                            .solidWhite,
                            .midnightNavy,
                            .slateGray,
                            .forestDark,
                            .particles
                        ]) { type in
                            WallpaperCard(
                                type: type,
                                isSelected: settings.currentWallpaper == type
                            ) {
                                AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    settings.currentWallpaper = type
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Section 2: Saved Custom Wallpapers Gallery
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.purple)
                        Text("SAVED CUSTOM WALLPAPERS")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .tracking(0.6)
                    }
                    
                    Spacer()
                    
                    Text("\(customManager.savedWallpapers.count) Saved")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button(action: chooseCustomWallpaper) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Add Wallpaper")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // "+ Add New" Quick Drop / Click Card
                        Button(action: chooseCustomWallpaper) {
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.20), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                        .frame(width: 135, height: 90)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.04))
                                        )
                                    
                                    VStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.blue)
                                        Text("Add Photo or Video")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                Text("New...")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Saved Custom Wallpaper Cards
                        ForEach(customManager.savedWallpapers) { item in
                            savedWallpaperCard(item: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Description of current selection
            HStack(spacing: 12) {
                Image(systemName: settings.currentWallpaper.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.currentWallpaper.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                    Text(settings.currentWallpaper.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 2)
        }
    }
    
    // MARK: - Framing & Crop Editor Panel
    
    @ViewBuilder
    private func framingEditorView(item: CustomWallpaperItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "crop")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                    Text("SELECT VISIBLE PART IN NOTCH")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button("Save & Done") {
                    customManager.updateWallpaperFraming(
                        id: item.id,
                        verticalOffset: framingState.verticalOffset,
                        scale: framingState.scale
                    )
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        framingState.framingItem = nil
                    }
                    AuralHapticsManager.shared.play(.completionChime, haptic: .generic)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            // Live Notch Cutout Preview
            HStack(spacing: 16) {
                ZStack {
                    Color.black
                        .frame(width: 220, height: 60)
                        .clipShape(NotchShape(topCornerRadius: 6, bottomCornerRadius: 14))
                    
                    if let img = customManager.thumbnail(for: item) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(framingState.scale)
                            .offset(y: (CGFloat(framingState.verticalOffset) - 0.5) * 60 * 0.8)
                            .frame(width: 220, height: 60)
                            .clipShape(NotchShape(topCornerRadius: 6, bottomCornerRadius: 14))
                    }
                    
                    NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        .frame(width: 220, height: 60)
                }
                .frame(width: 220, height: 60)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                
                // Sliders for Vertical Position and Zoom
                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Vertical Focus")
                                .font(.system(size: 10, weight: .semibold))
                            Spacer()
                            Text("\(Int(framingState.verticalOffset * 100))%")
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $framingState.verticalOffset, in: 0.0...1.0, step: 0.02)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Zoom / Scale")
                                .font(.system(size: 10, weight: .semibold))
                            Spacer()
                            Text("\(String(format: "%.1f", framingState.scale))x")
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $framingState.scale, in: 1.0...2.5, step: 0.05)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Saved Custom Wallpaper Card
    
    @ViewBuilder
    private func savedWallpaperCard(item: CustomWallpaperItem) -> some View {
        let isSelected = (settings.currentWallpaper == .custom && customManager.activeWallpaperID == item.id)
        let isHovered = (hoverState.hoveredItemID == item.id)
        
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button(action: {
                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        customManager.selectWallpaper(id: item.id)
                    }
                }) {
                    ZStack {
                        if let thumb = customManager.thumbnail(for: item) {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(item.scale)
                                .offset(y: (CGFloat(item.verticalOffset) - 0.5) * 40)
                                .frame(width: 135, height: 90)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 135, height: 90)
                            Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                        
                        // Mini Notch Outline
                        NotchShape(topCornerRadius: 4, bottomCornerRadius: 8)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                            .frame(width: 75, height: 16)
                            .position(x: 67, y: 8)
                        
                        // Badge (Video or Photo)
                        VStack {
                            Spacer()
                            HStack {
                                HStack(spacing: 3) {
                                    Image(systemName: item.isVideo ? "play.circle.fill" : "photo")
                                        .font(.system(size: 8))
                                    Text(item.isVideo ? "VIDEO" : "PHOTO")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Capsule())
                                .padding(5)
                                
                                Spacer()
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Top-right Action Buttons
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                            .background(Circle().fill(Color.white))
                    }
                    
                    // Framing / Crop Button
                    if isHovered || isSelected {
                        Button(action: {
                            framingState.framingItem = item
                            framingState.verticalOffset = item.verticalOffset
                            framingState.scale = item.scale
                            AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                        }) {
                            Image(systemName: "crop")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.blue.opacity(0.9))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Adjust Visible Framing / Crop")
                        
                        Button(action: {
                            AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                customManager.deleteWallpaper(id: item.id)
                            }
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.red.opacity(0.85))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Delete from Saved Wallpapers")
                    }
                }
                .padding(6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.15), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.35) : Color.black.opacity(0.12), radius: isSelected ? 5 : 2, y: 2)
            
            Text(item.name)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(.primary)
                .frame(width: 135)
                .lineLimit(1)
        }
        .onHover { hovering in
            hoverState.hoveredItemID = hovering ? item.id : nil
        }
    }
    
    // MARK: - File Picker Dialog
    
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
        panel.prompt = "Save to NotchX"
        panel.message = "Choose any photo or video to save to your NotchX wallpapers:"
        
        if panel.runModal() == .OK, let url = panel.url {
            AuralHapticsManager.shared.play(.whoosh, haptic: .levelChange)
            if let saved = customManager.saveWallpaper(from: url) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    customManager.selectWallpaper(id: saved.id)
                    framingState.framingItem = saved
                    framingState.verticalOffset = saved.verticalOffset
                    framingState.scale = saved.scale
                }
            }
        }
    }
}

// MARK: - Built-in Solid/Minimal Wallpaper Card

struct WallpaperCard: View {
    let type: WallpaperType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    WallpaperEngine(type: type, isActive: true)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(width: 135, height: 90)
                    
                    NotchShape(topCornerRadius: 4, bottomCornerRadius: 8)
                        .stroke(type == .solidWhite ? Color.black.opacity(0.4) : Color.white.opacity(0.35), lineWidth: 1)
                        .frame(width: 75, height: 16)
                        .position(x: 67, y: 8)
                    
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
