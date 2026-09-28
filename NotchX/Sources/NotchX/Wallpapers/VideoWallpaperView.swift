import SwiftUI
import AVFoundation
import AVKit

/// Video and custom media wallpaper player.
/// Automatically loops the video seamlessly when active.
/// When the notch collapses (cursor leaves), the player immediately pauses (sleeps)
/// to consume zero CPU and conserve battery.
struct VideoWallpaperView: View {
    let url: URL
    let isActive: Bool
    
    @ObservedObject private var playerModel = VideoPlayerModel()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                
                if playerModel.isImage, let nsImage = playerModel.staticImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else if let player = playerModel.player {
                    VideoLayerRepresentable(player: player)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
        }
        .onAppear {
            playerModel.setup(url: url)
            playerModel.updatePlayback(isActive: isActive)
        }
        .onChange(of: url) { _, newUrl in
            playerModel.setup(url: newUrl)
            playerModel.updatePlayback(isActive: isActive)
        }
        .onChange(of: isActive) { _, active in
            playerModel.updatePlayback(isActive: active)
        }
    }
}

/// Observable model managing AVPlayer lifecycle and seamless looping
class VideoPlayerModel: ObservableObject {
    @Published var player: AVQueuePlayer?
    @Published var staticImage: NSImage?
    @Published var isImage: Bool = false
    
    private var looper: AVPlayerLooper?
    private var currentURL: URL?
    
    func setup(url: URL) {
        guard currentURL != url else { return }
        currentURL = url
        
        let pathExt = url.pathExtension.lowercased()
        let imageExtensions = ["png", "jpg", "jpeg", "heic", "tiff", "gif", "webp"]
        
        if imageExtensions.contains(pathExt) {
            isImage = true
            staticImage = NSImage(contentsOf: url)
            player?.pause()
            player = nil
            looper = nil
            return
        }
        
        // Video file (.mp4, .mov, .m4v)
        isImage = false
        staticImage = nil
        
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        queuePlayer.isMuted = true // Wallpapers must always be muted
        queuePlayer.actionAtItemEnd = .none
        
        looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        self.player = queuePlayer
    }
    
    func updatePlayback(isActive: Bool) {
        guard !isImage, let player = player else { return }
        if isActive {
            player.play()
        } else {
            // Immediate sleep: stops frame rendering and frees video decoder
            player.pause()
        }
    }
    
    deinit {
        player?.pause()
        player = nil
        looper = nil
    }
}

/// AppKit AVPlayerLayer representable for optimal GPU-accelerated video rendering
struct VideoLayerRepresentable: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> NSView {
        let view = PlayerNSView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerView = nsView as? PlayerNSView {
            playerView.playerLayer.player = player
        }
    }
}

class PlayerNSView: NSView {
    let playerLayer = AVPlayerLayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}
