import Foundation
import AppKit
import AVFoundation

/// Metadata for a custom wallpaper saved inside NotchX
public struct CustomWallpaperItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var fileName: String
    public var isVideo: Bool
    public var dateAdded: Date
    public var verticalOffset: Double // 0.0 (top) to 1.0 (bottom), default 0.5 (center)
    public var scale: Double          // 1.0 to 2.5, default 1.0
    
    public init(id: UUID = UUID(), name: String, fileName: String, isVideo: Bool, dateAdded: Date = Date(), verticalOffset: Double = 0.5, scale: Double = 1.0) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.isVideo = isVideo
        self.dateAdded = dateAdded
        self.verticalOffset = verticalOffset
        self.scale = scale
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, fileName, isVideo, dateAdded, verticalOffset, scale
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.isVideo = try container.decode(Bool.self, forKey: .isVideo)
        self.dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        self.verticalOffset = try container.decodeIfPresent(Double.self, forKey: .verticalOffset) ?? 0.5
        self.scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
    }
}

/// Central persistence manager for custom wallpapers.
/// Stores uploaded photos and videos in Application Support with pre-cached thumbnails.
public class CustomWallpaperManager: ObservableObject {
    public static let shared = CustomWallpaperManager()
    
    @Published public var savedWallpapers: [CustomWallpaperItem] = []
    @Published public var activeWallpaperID: UUID? = nil
    
    private let defaults = UserDefaults.standard
    private let storageURL: URL
    private let thumbnailsURL: URL
    private let thumbCache = NSCache<NSString, NSImage>()
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.storageURL = appSupport.appendingPathComponent("NotchX/Wallpapers", isDirectory: true)
        self.thumbnailsURL = storageURL.appendingPathComponent("Thumbnails", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
        
        load()
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(savedWallpapers) {
            defaults.set(data, forKey: "notchx.savedCustomWallpapers")
        }
        if let activeID = activeWallpaperID {
            defaults.set(activeID.uuidString, forKey: "notchx.activeCustomWallpaperID")
        } else {
            defaults.removeObject(forKey: "notchx.activeCustomWallpaperID")
        }
    }
    
    private func load() {
        if let data = defaults.data(forKey: "notchx.savedCustomWallpapers"),
           let items = try? JSONDecoder().decode([CustomWallpaperItem].self, from: data) {
            self.savedWallpapers = items
        }
        if let idStr = defaults.string(forKey: "notchx.activeCustomWallpaperID"),
           let id = UUID(uuidString: idStr) {
            self.activeWallpaperID = id
        }
        
        // Migrate legacy single customWallpaperPath if needed
        let legacyPath = defaults.string(forKey: "notchx.customWallpaperPath") ?? ""
        if !legacyPath.isEmpty && savedWallpapers.isEmpty && FileManager.default.fileExists(atPath: legacyPath) {
            _ = saveWallpaper(from: URL(fileURLWithPath: legacyPath))
        }
    }
    
    // MARK: - Adding & Deleting Wallpapers
    
    public func saveWallpaper(from sourceURL: URL) -> CustomWallpaperItem? {
        let ext = sourceURL.pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "heic", "webp", "tiff", "bmp", "avif"]
        let videoExts = ["mp4", "mov", "m4v", "gif"]
        
        let isImg = imageExts.contains(ext)
        let isVid = videoExts.contains(ext)
        guard isImg || isVid else { return nil }
        
        let id = UUID()
        let destFileName = "\(id.uuidString).\(ext)"
        let destURL = storageURL.appendingPathComponent(destFileName)
        
        // Copy file into persistent application support storage
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            NSLog("❌ [CustomWallpaperManager] Failed to copy wallpaper: \(error)")
            return nil
        }
        
        // Generate high quality thumbnail
        generateThumbnail(for: destURL, id: id, isVideo: isVid)
        
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let item = CustomWallpaperItem(
            id: id,
            name: originalName.isEmpty ? "Wallpaper" : originalName,
            fileName: destFileName,
            isVideo: isVid
        )
        
        savedWallpapers.insert(item, at: 0)
        activeWallpaperID = item.id
        save()
        
        // Sync with SettingsManager
        SettingsManager.shared.currentWallpaper = .custom
        SettingsManager.shared.customWallpaperPath = destURL.path
        
        return item
    }
    
    public func deleteWallpaper(id: UUID) {
        guard let idx = savedWallpapers.firstIndex(where: { $0.id == id }) else { return }
        let item = savedWallpapers[idx]
        
        // Remove file and thumbnail
        let fileURL = storageURL.appendingPathComponent(item.fileName)
        let thumbURL = thumbnailsURL.appendingPathComponent("\(id.uuidString).png")
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: thumbURL)
        thumbCache.removeObject(forKey: id.uuidString as NSString)
        
        savedWallpapers.remove(at: idx)
        
        if activeWallpaperID == id {
            if let first = savedWallpapers.first {
                selectWallpaper(id: first.id)
            } else {
                activeWallpaperID = nil
                SettingsManager.shared.customWallpaperPath = ""
                SettingsManager.shared.currentWallpaper = .solidBlack
            }
        }
        
        save()
    }
    
    public func selectWallpaper(id: UUID) {
        guard let item = savedWallpapers.first(where: { $0.id == id }) else { return }
        activeWallpaperID = id
        let fileURL = storageURL.appendingPathComponent(item.fileName)
        SettingsManager.shared.customWallpaperPath = fileURL.path
        SettingsManager.shared.currentWallpaper = .custom
        save()
    }
    
    public var activeItem: CustomWallpaperItem? {
        guard let id = activeWallpaperID else { return savedWallpapers.first }
        return savedWallpapers.first(where: { $0.id == id })
    }
    
    public func updateWallpaperFraming(id: UUID, verticalOffset: Double, scale: Double) {
        if let idx = savedWallpapers.firstIndex(where: { $0.id == id }) {
            savedWallpapers[idx].verticalOffset = verticalOffset
            savedWallpapers[idx].scale = scale
            save()
        }
    }
    
    // MARK: - File & Thumbnail Resolution
    
    public func fileURL(for item: CustomWallpaperItem) -> URL {
        return storageURL.appendingPathComponent(item.fileName)
    }
    
    public func thumbnail(for item: CustomWallpaperItem) -> NSImage? {
        if let cached = thumbCache.object(forKey: item.id.uuidString as NSString) {
            return cached
        }
        
        let thumbURL = thumbnailsURL.appendingPathComponent("\(item.id.uuidString).png")
        if let img = NSImage(contentsOf: thumbURL) {
            thumbCache.setObject(img, forKey: item.id.uuidString as NSString)
            return img
        }
        
        // Lazy regeneration if thumbnail missing
        let fileURL = fileURL(for: item)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            generateThumbnail(for: fileURL, id: item.id, isVideo: item.isVideo)
            if let img = NSImage(contentsOf: thumbURL) {
                thumbCache.setObject(img, forKey: item.id.uuidString as NSString)
                return img
            }
        }
        
        return nil
    }
    
    private func generateThumbnail(for url: URL, id: UUID, isVideo: Bool) {
        let thumbDest = thumbnailsURL.appendingPathComponent("\(id.uuidString).png")
        let thumbSize = NSSize(width: 240, height: 150)
        
        if isVideo {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = thumbSize
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let rep = NSBitmapImageRep(cgImage: cgImage)
                if let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: thumbDest)
                }
            }
        } else {
            if let original = NSImage(contentsOf: url) {
                let targetRect = NSRect(origin: .zero, size: thumbSize)
                let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: Int(thumbSize.width),
                    pixelsHigh: Int(thumbSize.height),
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                )
                if let rep = rep {
                    NSGraphicsContext.saveGraphicsState()
                    let ctx = NSGraphicsContext(bitmapImageRep: rep)
                    NSGraphicsContext.current = ctx
                    original.draw(in: targetRect, from: .zero, operation: .copy, fraction: 1.0)
                    NSGraphicsContext.restoreGraphicsState()
                    if let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: thumbDest)
                    }
                }
            }
        }
    }
}
