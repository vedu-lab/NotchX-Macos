import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// A file, photo, or folder stored temporarily in the notch tray
struct TrayFile: Identifiable {
    let id: UUID
    let url: URL
    var name: String
    var icon: NSImage
    var isDirectory: Bool
}

/// Manages the temporary file tray with persistent in-memory session storage
class FileTrayManager: ObservableObject, @unchecked Sendable {
    static let shared = FileTrayManager()
    static let maxFiles = 20
    
    @Published var files: [TrayFile] = []
    
    @MainActor
    func addFile(url: URL) {
        guard files.count < Self.maxFiles else { return }
        // Prevent duplicate URLs
        guard !files.contains(where: { $0.url == url }) else { return }
        NotchPhysicsEngine.shared.triggerDropImpact()
        AuralHapticsManager.shared.play(.whoosh, haptic: .levelChange)
        
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 40, height: 40)
        
        let newFile = TrayFile(
            id: UUID(),
            url: url,
            name: url.lastPathComponent,
            icon: icon,
            isDirectory: isDir.boolValue
        )
        files.append(newFile)
    }
    
    @MainActor
    func addProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                    var targetURL: URL?
                    if let url = item as? URL {
                        targetURL = url
                    } else if let nsurl = item as? NSURL {
                        targetURL = nsurl as URL
                    } else if let data = item as? Data,
                              let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                              !str.isEmpty {
                        targetURL = str.hasPrefix("file://") ? URL(string: str) : URL(fileURLWithPath: str)
                    }
                    if let finalURL = targetURL {
                        DispatchQueue.main.async {
                            self?.addFile(url: finalURL)
                        }
                    }
                }
            } else if provider.canLoadObject(ofClass: NSURL.self) {
                _ = provider.loadObject(ofClass: NSURL.self) { [weak self] nsurl, _ in
                    if let url = nsurl as? URL {
                        DispatchQueue.main.async {
                            self?.addFile(url: url)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, _ in
                    var imageData: Data?
                    if let img = item as? NSImage,
                       let tiff = img.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff) {
                        imageData = rep.representation(using: .png, properties: [:])
                    } else if let data = item as? Data {
                        imageData = data
                    }
                    
                    if let data = imageData {
                        let tempFile = FileManager.default.temporaryDirectory
                            .appendingPathComponent("DroppedPhoto_\(Int(Date().timeIntervalSince1970)).png")
                        try? data.write(to: tempFile)
                        DispatchQueue.main.async {
                            self?.addFile(url: tempFile)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.item.identifier, options: nil) { [weak self] item, _ in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            self?.addFile(url: url)
                        }
                    } else if let nsurl = item as? NSURL {
                        DispatchQueue.main.async {
                            self?.addFile(url: nsurl as URL)
                        }
                    }
                }
            }
        }
    }
    
    func removeFile(id: UUID) {
        files.removeAll { $0.id == id }
    }
    
    func clearAll() {
        files.removeAll()
    }
}

/// File Tray tab — drag files in temporarily, drag them out to other apps.
/// Perfectly aligned with 16pt inward margins and spacious balanced padding.
struct FileTrayView: View {
    @ObservedObject var manager = FileTrayManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            if manager.files.isEmpty {
                // Empty drop zone with dashed border, perfectly aligned inwards
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white.opacity(0.70))
                    
                    Text("Drop files, photos, or folders here")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Stored temporarily while you switch between apps")
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.50))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .padding(.top, 2)
            } else {
                // Header with file count badge and Clear All button
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 10))
                        Text("\(manager.files.count) items stored")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.75))
                    
                    Spacer()
                    
                    Button("Clear All") {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            manager.clearAll()
                        }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                
                // Horizontal scrollable row of stored files
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(manager.files) { file in
                            FileItemView(file: file) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    manager.removeFile(id: file.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)
                .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL, UTType.item, UTType.image, UTType.data], isTargeted: nil) { providers in
            manager.addProviders(providers)
            return true
        }
    }
}

/// Individual file item in the tray — draggable out into other applications
struct FileItemView: View {
    let file: TrayFile
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                // File / App / Folder Icon
                Image(nsImage: file.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                
                // Remove X Button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.90))
                        .background(Circle().fill(Color.black.opacity(0.65)))
                }
                .buttonStyle(PlainButtonStyle())
                .offset(x: 7, y: -7)
            }
            
            Text(file.name)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.white.opacity(0.90))
                .lineLimit(1)
                .frame(width: 64)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
    }
}
