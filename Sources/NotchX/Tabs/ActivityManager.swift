import Foundation
import AppKit
import Combine
import AVFoundation
import CoreAudio

enum ActiveSourceType {
    case videoCall(appName: String)
    case browserMedia(browserName: String, title: String, url: String)
    case music(track: String, artist: String, isPlaying: Bool)
    case idle
}

/// Manages background activity detection including video calls, browser media, and music players.
/// Features a robust 3-check verification system:
/// 1. Hardware Microphone Stream Check (CoreAudio)
/// 2. Hardware Camera In-Use Check (AVFoundation)
/// 3. Active Process & Web Meeting Inspection (FaceTime, Zoom, Google Meet, Teams, Slack, Discord, WhatsApp)
class ActivityManager: ObservableObject {
    static let shared = ActivityManager()
    
    @Published var currentSource: ActiveSourceType = .idle
    @Published var isMicMuted: Bool = false
    @Published var isCameraOff: Bool = false
    @Published var isCallActive: Bool = false
    @Published var callAppName: String = ""
    @Published var browserMediaTitle: String = ""
    @Published var browserName: String = ""
    @Published var isNotchExpanded: Bool = false
    
    private var pollTimer: Timer?
    private var collapsedTicks: Int = 0
    private let queue = DispatchQueue(label: "com.notchx.activity", qos: .userInitiated)
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        checkActivity()
        // Relaxed 4.0s polling for background activity (video calls, browser media)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.checkActivity()
        }
    }
    
    func checkActivity() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // === CHECK 1: Active Video / Audio Call ===
            if let callApp = self.detectActiveCallWithThreeChecks() {
                DispatchQueue.main.async {
                    self.isCallActive = true
                    self.callAppName = callApp
                    self.currentSource = .videoCall(appName: callApp)
                }
                return
            }
            
            // === CHECK 2: Music (Apple Music / Spotify) — Fast in-memory check ===
            let music = NowPlayingManager.shared
            if music.isMusicRunning && (!music.trackName.isEmpty || music.isPlaying) {
                DispatchQueue.main.async {
                    self.isCallActive = false
                    self.currentSource = .music(
                        track: music.trackName,
                        artist: music.artistName,
                        isPlaying: music.isPlaying
                    )
                }
                return
            }
            
            // === CHECK 3: Browser Media Playback (YouTube, Netflix, etc.) ===
            // Throttle browser tab inspection when collapsed (every 3rd cycle = ~12s)
            // When user expands notch, checkActivity is invoked immediately for 0ms freshness
            let shouldCheckBrowser = self.isNotchExpanded || (self.collapsedTicks % 3 == 0)
            self.collapsedTicks &+= 1
            
            if shouldCheckBrowser, let browserInfo = self.detectBrowserMedia() {
                DispatchQueue.main.async {
                    self.isCallActive = false
                    self.browserName = browserInfo.browser
                    self.browserMediaTitle = browserInfo.title
                    self.currentSource = .browserMedia(
                        browserName: browserInfo.browser,
                        title: browserInfo.title,
                        url: browserInfo.url
                    )
                }
                return
            }
            
            // === IDLE STATE ===
            DispatchQueue.main.async {
                self.isCallActive = false
                self.currentSource = .idle
            }
        }
    }
    
    // MARK: - 3-Check Video Call Detection
    
    /// Multi-layered check combining hardware stream verification, dedicated application state, and browser meeting inspection
    private func detectActiveCallWithThreeChecks() -> String? {
        let micActive = isMicrophoneActive()
        
        let running = NSWorkspace.shared.runningApplications
        let hasMeetingApp = running.contains { app in
            guard let b = app.bundleIdentifier else { return false }
            return b == "com.apple.FaceTime" ||
                   b.contains("zoom.us") ||
                   b.contains("teams") ||
                   b.contains("webex") ||
                   b.contains("tinyspeck.slack") ||
                   b.contains("Slack") ||
                   b.contains("discord") ||
                   b.contains("WhatsApp")
        }
        
        // Fast path: if microphone is not active and no dedicated meeting app is open,
        // no call is occurring. Avoid heavy camera discovery and browser tab scripting!
        if !micActive && !hasMeetingApp {
            return nil
        }
        
        let camActive = isCameraInUse()
        
        // CHECK 1: Native Meeting Applications
        for app in running {
            guard let bundleID = app.bundleIdentifier else { continue }
            
            if bundleID == "com.apple.FaceTime" {
                if micActive || camActive || !app.isHidden {
                    return "FaceTime"
                }
            }
            if bundleID.contains("zoom.us") {
                if micActive || camActive || isZoomMeetingRunning() {
                    return "Zoom"
                }
            }
            if bundleID.contains("teams") && (micActive || camActive) {
                return "Microsoft Teams"
            }
            if bundleID.contains("webex") && (micActive || camActive) {
                return "Webex"
            }
            if (bundleID.contains("tinyspeck.slack") || bundleID.contains("Slack")) && micActive {
                return "Slack"
            }
            if bundleID.contains("discord") && micActive {
                return "Discord"
            }
            if bundleID.contains("WhatsApp") && (micActive || camActive) {
                return "WhatsApp"
            }
        }
        
        // CHECK 2: In-Browser Video Meetings (Google Meet, Zoom Web, Teams Web, Webex)
        // Only inspect browser tabs if mic or camera is currently active!
        if micActive || camActive {
            if let browserMeeting = checkBrowserMeetings() {
                return browserMeeting
            }
        }
        
        // CHECK 3: Hardware Fallback — Camera in active use by another app
        if camActive {
            return "Video Call"
        }
        
        return nil
    }
    
    /// Check 1: Hardware CoreAudio microphone input stream active
    private func isMicrophoneActive() -> Bool {
        var inputDeviceID = AudioDeviceID(0)
        var prop = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &prop, 0, nil, &size, &inputDeviceID) == 0 else {
            return false
        }
        
        var isRunning: UInt32 = 0
        var runProp = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var runSize = UInt32(MemoryLayout<UInt32>.size)
        let err = AudioObjectGetPropertyData(inputDeviceID, &runProp, 0, nil, &runSize, &isRunning)
        return err == 0 && isRunning != 0
    }
    
    /// Check 2: Hardware AVFoundation camera in active use
    private func isCameraInUse() -> Bool {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        return session.devices.contains { $0.isInUseByAnotherApplication }
    }
    
    /// Check 3A: Inspect running browser tabs for Google Meet, Zoom, Teams, Webex
    private func checkBrowserMeetings() -> String? {
        let running = NSWorkspace.shared.runningApplications
        let hasSafari = running.contains { $0.bundleIdentifier == "com.apple.Safari" }
        let hasChrome = running.contains { $0.bundleIdentifier == "com.google.Chrome" }
        let hasArc = running.contains { $0.bundleIdentifier == "company.thebrowser.Browser" }
        let hasBrave = running.contains { $0.bundleIdentifier == "com.brave.Browser" }
        
        if hasSafari {
            let script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabURL to URL of t
                            set tabTitle to name of t
                            if tabURL contains "meet.google.com" or tabTitle starts with "Meet - " then
                                return "Google Meet"
                            else if tabURL contains "zoom.us/j" or tabTitle contains "Zoom Meeting" then
                                return "Zoom"
                            else if tabURL contains "teams.microsoft.com" then
                                return "Microsoft Teams"
                            end if
                        end repeat
                    end repeat
                end if
            end tell
            """
            if let result = executeAppleScript(script), !result.isEmpty {
                return result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if hasChrome || hasArc || hasBrave {
            let targetApp = hasChrome ? "Google Chrome" : (hasArc ? "Arc" : "Brave Browser")
            let script = """
            tell application "\(targetApp)"
                if (count of windows) > 0 then
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabURL to URL of t
                            set tabTitle to title of t
                            if tabURL contains "meet.google.com" or tabTitle starts with "Meet - " then
                                return "Google Meet"
                            else if tabURL contains "zoom.us/j" or tabTitle contains "Zoom Meeting" then
                                return "Zoom"
                            else if tabURL contains "teams.microsoft.com" then
                                return "Microsoft Teams"
                            end if
                        end repeat
                    end repeat
                end if
            end tell
            """
            if let result = executeAppleScript(script), !result.isEmpty {
                return result.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    private func isZoomMeetingRunning() -> Bool {
        let script = """
        tell application "System Events"
            if exists process "zoom.us" then
                tell process "zoom.us"
                    repeat with w in windows
                        if name of w contains "Meeting" or name of w contains "Zoom" then
                            return "yes"
                        end if
                    end repeat
                end tell
            end if
        end tell
        return "no"
        """
        return executeAppleScript(script)?.contains("yes") == true
    }
    
    // MARK: - Video Call Controls
    
    func endCurrentCall() {
        if callAppName == "FaceTime" {
            runAppleScript("""
            tell application "FaceTime" to quit
            """)
        } else if callAppName == "Zoom" {
            runAppleScript("""
            tell application "System Events" to tell process "zoom.us"
                keystroke "w" using command down
            end tell
            """)
        } else if callAppName == "Google Meet" {
            runAppleScript("""
            tell application "Safari"
                if (count of windows) > 0 then
                    repeat with w in windows
                        close (tabs of w whose URL contains "meet.google.com")
                    end repeat
                end if
            end tell
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    repeat with w in windows
                        close (tabs of w whose URL contains "meet.google.com")
                    end repeat
                end if
            end tell
            """)
        } else {
            runAppleScript("tell application \"\(callAppName)\" to quit")
        }
        
        DispatchQueue.main.async {
            self.isCallActive = false
            self.currentSource = .idle
        }
    }
    
    func toggleMicrophoneMute() {
        isMicMuted.toggle()
        let volume = isMicMuted ? 0 : 100
        runAppleScript("set volume input volume \(volume)")
        
        // Also send native meeting mute shortcuts
        if callAppName == "Zoom" {
            runAppleScript("tell application \"System Events\" to tell process \"zoom.us\" to keystroke \"a\" using {command down, shift down}")
        } else if callAppName == "Google Meet" {
            runAppleScript("tell application \"System Events\" to keystroke \"d\" using command down")
        } else if callAppName == "FaceTime" {
            runAppleScript("tell application \"System Events\" to tell process \"FaceTime\" to keystroke \"m\" using {command down, shift down}")
        }
    }
    
    func toggleCamera() {
        isCameraOff.toggle()
        if callAppName == "Zoom" {
            runAppleScript("tell application \"System Events\" to tell process \"zoom.us\" to keystroke \"v\" using {command down, shift down}")
        } else if callAppName == "Google Meet" {
            runAppleScript("tell application \"System Events\" to keystroke \"e\" using command down")
        } else if callAppName == "FaceTime" {
            runAppleScript("tell application \"System Events\" to tell process \"FaceTime\" to keystroke \"v\" using {command down, shift down}")
        }
    }
    
    // MARK: - Browser Video Playback Detection & Controls
    
    private func detectBrowserMedia() -> (browser: String, title: String, url: String)? {
        let running = NSWorkspace.shared.runningApplications
        let hasSafari = running.contains { $0.bundleIdentifier == "com.apple.Safari" }
        let hasChrome = running.contains { $0.bundleIdentifier == "com.google.Chrome" }
        
        if hasSafari {
            let script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    set currentTab to current tab of front window
                    return (name of currentTab) & "|||" & (URL of currentTab)
                end if
            end tell
            """
            if let output = executeAppleScript(script) {
                let parts = output.components(separatedBy: "|||")
                if parts.count == 2 {
                    let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let url = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if isMediaTitleOrURL(title: title, url: url) {
                        return ("Safari", cleanMediaTitle(title), url)
                    }
                }
            }
        }
        
        if hasChrome {
            let script = """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    set currentTab to active tab of front window
                    return (title of currentTab) & "|||" & (URL of currentTab)
                end if
            end tell
            """
            if let output = executeAppleScript(script) {
                let parts = output.components(separatedBy: "|||")
                if parts.count == 2 {
                    let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let url = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    if isMediaTitleOrURL(title: title, url: url) {
                        return ("Chrome", cleanMediaTitle(title), url)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func isMediaTitleOrURL(title: String, url: String) -> Bool {
        let mediaKeywords = ["youtube.com", "youtu.be", "netflix.com", "twitch.tv", "vimeo.com", "primevideo.com", "disneyplus.com", "spotify.com", "soundcloud.com"]
        let lowerUrl = url.lowercased()
        let lowerTitle = title.lowercased()
        return mediaKeywords.contains { lowerUrl.contains($0) } || lowerTitle.contains("youtube") || lowerTitle.contains("netflix")
    }
    
    private func cleanMediaTitle(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: " - YouTube", with: "")
            .replacingOccurrences(of: " | Netflix", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func playPauseBrowserMedia() {
        let targetApp = browserName == "Safari" ? "Safari" : "Google Chrome"
        runAppleScript("""
        tell application "\(targetApp)"
            activate
            tell application "System Events" to key code 49
        end tell
        """)
    }
    
    // MARK: - AppleScript Helpers
    
    private func executeAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let output = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return output.stringValue
    }
    
    private func runAppleScript(_ source: String) {
        queue.async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                script.executeAndReturnError(&error)
            }
        }
    }
}
