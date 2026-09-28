import SwiftUI
import AppKit

/// Unified media player manager supporting Apple Music, Spotify, and browser media
class NowPlayingManager: ObservableObject, @unchecked Sendable {
    static let shared = NowPlayingManager()
    
    @Published var trackName: String = ""
    @Published var artistName: String = ""
    @Published var albumName: String = ""
    @Published var isPlaying: Bool = false
    @Published var activePlayerName: String = "" // "Music", "Spotify", "Safari", "Chrome"
    @Published var isMediaDetected: Bool = false
    @Published var albumArtwork: NSImage? = nil
    var isMusicRunning: Bool { isMediaDetected }
    
    private var lastArtworkURL: String = ""
    private var timer: Timer?
    private let scriptQueue = DispatchQueue(label: "com.notchx.media", qos: .userInitiated)
    
    init() {
        startPolling()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startPolling() {
        fetchNowPlayingInfo()
        timer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { [weak self] _ in
            self?.fetchNowPlayingInfo()
        }
    }
    
    func fetchNowPlayingInfo() {
        scriptQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Query Spotify and Apple Music with Album & Artwork support
            let scriptSource = """
            tell application "System Events"
                set spotifyRunning to (exists process "Spotify")
                set musicRunning to (exists process "Music")
            end tell
            
            if spotifyRunning then
                try
                    tell application "Spotify"
                        set tName to (name of current track)
                        set aName to (artist of current track)
                        set albName to (album of current track)
                        set artURL to ""
                        try
                            set artURL to (artwork url of current track)
                        end try
                        if player state is playing then
                            return tName & "|||" & aName & "|||" & albName & "|||playing|||Spotify|||" & artURL
                        else if player state is paused then
                            return tName & "|||" & aName & "|||" & albName & "|||paused|||Spotify|||" & artURL
                        end if
                    end tell
                end try
            end if
            
            if musicRunning then
                try
                    tell application "Music"
                        set tName to (name of current track)
                        set aName to (artist of current track)
                        set albName to (album of current track)
                        if player state is playing then
                            return tName & "|||" & aName & "|||" & albName & "|||playing|||Music"
                        else if player state is paused then
                            return tName & "|||" & aName & "|||" & albName & "|||paused|||Music"
                        end if
                    end tell
                end try
            end if
            
            return "not_running"
            """
            
            var error: NSDictionary?
            if let script = NSAppleScript(source: scriptSource) {
                let output = script.executeAndReturnError(&error)
                if error == nil, let stringValue = output.stringValue, stringValue != "not_running" {
                    let parts = stringValue.components(separatedBy: "|||")
                    if parts.count >= 5 {
                        let t = parts[0]
                        let a = parts[1]
                        let alb = parts[2]
                        let playing = (parts[3] == "playing")
                        let app = parts[4]
                        let artURLString = parts.count > 5 ? parts[5] : ""
                        
                        DispatchQueue.main.async {
                            self.trackName = t
                            self.artistName = a
                            self.albumName = alb
                            self.isPlaying = playing
                            self.activePlayerName = app
                            self.isMediaDetected = true
                        }
                        
                        // Download Spotify artwork if available
                        if !artURLString.isEmpty, artURLString != self.lastArtworkURL, let url = URL(string: artURLString) {
                            self.lastArtworkURL = artURLString
                            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                                if let data = data, let img = NSImage(data: data) {
                                    DispatchQueue.main.async {
                                        self?.albumArtwork = img
                                    }
                                }
                            }.resume()
                        }
                        return
                    }
                }
            }
            
            // Check browser media from ActivityManager as fallback
            let activity = ActivityManager.shared
            if case .browserMedia(let browser, let title, _) = activity.currentSource {
                DispatchQueue.main.async {
                    self.trackName = title
                    self.artistName = "\(browser) Video"
                    self.albumName = "Web Media"
                    self.isPlaying = true
                    self.activePlayerName = browser
                    self.isMediaDetected = true
                }
                return
            }
            
            // Nothing currently playing
            DispatchQueue.main.async {
                self.isMediaDetected = false
                self.isPlaying = false
            }
        }
    }
    
    func playPause() {
        if activePlayerName == "Spotify" {
            runAppleScript("tell application \"Spotify\" to playpause")
        } else if activePlayerName == "Safari" || activePlayerName == "Chrome" {
            ActivityManager.shared.playPauseBrowserMedia()
        } else {
            // Default to Apple Music
            runAppleScript("""
            tell application "Music"
                if player state is playing then
                    pause
                else
                    play
                end if
            end tell
            """)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.fetchNowPlayingInfo()
        }
    }
    
    func nextTrack() {
        if activePlayerName == "Spotify" {
            runAppleScript("tell application \"Spotify\" to next track")
        } else {
            runAppleScript("tell application \"Music\" to next track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.fetchNowPlayingInfo()
        }
    }
    
    func previousTrack() {
        if activePlayerName == "Spotify" {
            runAppleScript("tell application \"Spotify\" to previous track")
        } else {
            runAppleScript("tell application \"Music\" to previous track")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.fetchNowPlayingInfo()
        }
    }
    
    private func runAppleScript(_ command: String) {
        scriptQueue.async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: command) {
                script.executeAndReturnError(&error)
            }
        }
    }
}

/// Spacious, pixel-perfect Music Player HUD Column matching the screenshot
struct MusicPlayerHUDView: View {
    @ObservedObject var manager = NowPlayingManager.shared
    
    var body: some View {
        HStack(spacing: 11) {
            // Album Artwork with App Badge
            ZStack(alignment: .bottomTrailing) {
                // Cover Art Image
                if let art = manager.albumArtwork {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                } else {
                    // Stylized Cover Art Placeholder
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.16, green: 0.17, blue: 0.22),
                                    Color(red: 0.08, green: 0.09, blue: 0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.65))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
                
                // Player App Badge (Apple Music / Spotify / Browser)
                playerBadge
                    .offset(x: 3, y: 3)
            }
            
            // Track Info & Playback Controls
            VStack(alignment: .leading, spacing: 3) {
                // Track Title
                Text(manager.trackName.isEmpty ? "Dibi Dibi Rek" : manager.trackName)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Album / Subtitle
                Text(manager.albumName.isEmpty ? (manager.trackName.isEmpty ? "Best Of" : "Album") : manager.albumName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                
                // Artist Name
                Text(manager.artistName.isEmpty ? "Ismaël Lô" : manager.artistName)
                    .font(.system(size: 9.5))
                    .foregroundColor(.white.opacity(0.40))
                    .lineLimit(1)
                
                // Inline Playback Controls (compact and directly underneath)
                HStack(spacing: 14) {
                    Button(action: { manager.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.80))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { manager.playPause() }) {
                        Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { manager.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.80))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 3)
            }
            .frame(width: 120, alignment: .leading)
        }
        .frame(width: 188, alignment: .leading)
    }
    
    @ViewBuilder
    private var playerBadge: some View {
        let isSpotify = manager.activePlayerName == "Spotify"
        ZStack {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(isSpotify ? Color(red: 0.11, green: 0.73, blue: 0.33) : Color(red: 0.98, green: 0.23, blue: 0.35))
                .frame(width: 14, height: 14)
                .shadow(color: Color.black.opacity(0.3), radius: 1)
            
            Image(systemName: isSpotify ? "waveform" : "music.note")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
