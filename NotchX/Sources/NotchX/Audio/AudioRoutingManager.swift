import Foundation
import AppKit
import CoreAudio
import AudioToolbox
import Combine

/// Represents an audio output device available on the Mac
public struct AudioOutputDevice: Identifiable, Equatable {
    public let id: AudioDeviceID
    public let name: String
    public let uid: String
    public let isDefault: Bool
    public let iconName: String
    
    public static func == (lhs: AudioOutputDevice, rhs: AudioOutputDevice) -> Bool {
        lhs.id == rhs.id && lhs.isDefault == rhs.isDefault
    }
}

/// Represents an application producing audio or communication streams
public struct AppAudioTrack: Identifiable, Equatable {
    public var id: String { bundleID }
    public let bundleID: String
    public let name: String
    public let icon: NSImage?
    public var volume: Double // 0.0 to 1.0
    public var isMuted: Bool
    public var isSupportedDirectly: Bool
    
    public static func == (lhs: AppAudioTrack, rhs: AppAudioTrack) -> Bool {
        lhs.bundleID == rhs.bundleID && lhs.volume == rhs.volume && lhs.isMuted == rhs.isMuted
    }
}

/// Manages per-app volume attenuation and 1-click CoreAudio hardware output routing.
/// Allows muting Spotify while keeping Zoom at 100%, and switching output from
/// Built-in Speakers to AirPods / External Displays instantly.
public class AudioRoutingManager: ObservableObject {
    public static let shared = AudioRoutingManager()
    
    @Published public var outputDevices: [AudioOutputDevice] = []
    @Published public var activeAppTracks: [AppAudioTrack] = []
    @Published public var defaultDeviceID: AudioDeviceID = 0
    @Published public var masterVolume: Double = 0.75
    
    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.notchx.audiorouting", qos: .userInitiated)
    
    // Cached volumes to restore upon unmute
    private var preMuteVolumes: [String: Double] = [:]
    
    private init() {
        refreshDevices()
        refreshAppTracks()
        setupDeviceChangeListener()
        
        // Periodic check to detect newly opened/closed media apps
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.refreshDevices()
            self?.refreshAppTracks()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - CoreAudio Device Enumeration & Routing
    
    public func refreshDevices() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var propertySize: UInt32 = 0
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let status = AudioObjectGetPropertyDataSize(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &propertySize
            )
            
            guard status == noErr, propertySize > 0 else { return }
            
            let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
            var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
            
            let fetchStatus = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &propertySize,
                &deviceIDs
            )
            
            guard fetchStatus == noErr else { return }
            
            let currentDefaultID = self.getDefaultOutputDeviceID()
            var outputs: [AudioOutputDevice] = []
            
            for id in deviceIDs {
                // Check if device supports output streams
                if self.deviceSupportsOutput(id) {
                    let name = self.getDeviceName(id)
                    let uid = self.getDeviceUID(id)
                    let icon = self.getIconForDevice(id, name: name)
                    let isDef = (id == currentDefaultID)
                    
                    outputs.append(
                        AudioOutputDevice(
                            id: id,
                            name: name,
                            uid: uid,
                            isDefault: isDef,
                            iconName: icon
                        )
                    )
                }
            }
            
            DispatchQueue.main.async {
                self.defaultDeviceID = currentDefaultID
                self.outputDevices = outputs
            }
        }
    }
    
    /// Switch active audio output device with one click via CoreAudio
    public func selectOutputDevice(id: AudioDeviceID) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var targetID = id
            let size = UInt32(MemoryLayout<AudioDeviceID>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                size,
                &targetID
            )
            
            if status == noErr {
                DispatchQueue.main.async {
                    self.defaultDeviceID = targetID
                    self.refreshDevices()
                }
            }
        }
    }
    
    private func getDefaultOutputDeviceID() -> AudioDeviceID {
        var defaultID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &defaultID
        )
        
        return status == noErr ? defaultID : 0
    }
    
    private func deviceSupportsOutput(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        guard status == noErr, size > 0 else { return false }
        
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }
        
        let fetchStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferListPointer)
        guard fetchStatus == noErr else { return false }
        
        let bufferList = bufferListPointer.pointee
        return bufferList.mNumberBuffers > 0
    }
    
    private func getDeviceName(_ deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        if status == noErr, let cfStr = name?.takeRetainedValue() {
            return cfStr as String
        }
        return "Audio Output"
    }
    
    private func getDeviceUID(_ deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid)
        if status == noErr, let cfStr = uid?.takeRetainedValue() {
            return cfStr as String
        }
        return UUID().uuidString
    }
    
    private func getIconForDevice(_ deviceID: AudioDeviceID, name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpod") {
            return "airpodspro"
        } else if lower.contains("headphone") || lower.contains("beats") || lower.contains("sony") || lower.contains("bose") {
            return "headphones"
        } else if lower.contains("display") || lower.contains("hdmi") || lower.contains("tv") || lower.contains("monitor") {
            return "display"
        } else if lower.contains("speaker") || lower.contains("built-in") || lower.contains("macbook") {
            return "speaker.wave.2.fill"
        }
        return "speaker.wave.3.fill"
    }
    
    private func setupDeviceChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            { (_, _, _, clientData) -> OSStatus in
                guard let clientData = clientData else { return noErr }
                let manager = Unmanaged<AudioRoutingManager>.fromOpaque(clientData).takeUnretainedValue()
                manager.refreshDevices()
                return noErr
            },
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
    
    // MARK: - Per-App Volume & Routing
    
    public func refreshAppTracks() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let running = NSWorkspace.shared.runningApplications
            var detectedTracks: [AppAudioTrack] = []
            
            // Priority audio producing targets
            let priorityAudioBundleIDs: [(bundleID: String, name: String, isDirect: Bool)] = [
                ("com.spotify.client", "Spotify", true),
                ("com.apple.Music", "Apple Music", true),
                ("us.zoom.xos", "Zoom", false),
                ("com.google.Chrome", "Google Chrome", false),
                ("com.apple.Safari", "Safari", false),
                ("company.thebrowser.Browser", "Arc", false),
                ("com.brave.Browser", "Brave", false),
                ("com.apple.FaceTime", "FaceTime", false),
                ("com.tinyspeck.slackmacgap", "Slack", false),
                ("com.hnc.Discord", "Discord", false)
            ]
            
            for target in priorityAudioBundleIDs {
                if let app = running.first(where: { $0.bundleIdentifier == target.bundleID }) {
                    let volume = self.fetchAppVolume(bundleID: target.bundleID, isDirect: target.isDirect)
                    let isMuted = volume == 0
                    
                    let track = AppAudioTrack(
                        bundleID: target.bundleID,
                        name: app.localizedName ?? target.name,
                        icon: app.icon,
                        volume: volume,
                        isMuted: isMuted,
                        isSupportedDirectly: target.isDirect
                    )
                    detectedTracks.append(track)
                }
            }
            
            DispatchQueue.main.async {
                self.activeAppTracks = detectedTracks
            }
        }
    }
    
    private func fetchAppVolume(bundleID: String, isDirect: Bool) -> Double {
        if bundleID == "com.spotify.client" {
            let script = "tell application \"Spotify\" to get sound volume"
            if let result = executeAppleScript(script), let vol = Double(result.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return vol / 100.0
            }
        } else if bundleID == "com.apple.Music" {
            let script = "tell application \"Music\" to get sound volume"
            if let result = executeAppleScript(script), let vol = Double(result.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return vol / 100.0
            }
        }
        
        // Return cached or default 1.0 for other apps
        return preMuteVolumes[bundleID] ?? 1.0
    }
    
    /// Set individual application volume
    public func setAppVolume(bundleID: String, volume: Double) {
        let clamped = max(0.0, min(1.0, volume))
        
        // Update local state immediately for 60fps slider responsiveness
        if let idx = activeAppTracks.firstIndex(where: { $0.bundleID == bundleID }) {
            activeAppTracks[idx].volume = clamped
            activeAppTracks[idx].isMuted = clamped == 0
        }
        
        preMuteVolumes[bundleID] = clamped
        
        queue.async {
            if bundleID == "com.spotify.client" {
                let intVol = Int(clamped * 100)
                _ = executeAppleScript("tell application \"Spotify\" to set sound volume to \(intVol)")
            } else if bundleID == "com.apple.Music" {
                let intVol = Int(clamped * 100)
                _ = executeAppleScript("tell application \"Music\" to set sound volume to \(intVol)")
            }
        }
    }
    
    /// Toggle mute for a specific application
    public func toggleAppMute(bundleID: String) {
        guard let track = activeAppTracks.first(where: { $0.bundleID == bundleID }) else { return }
        
        if track.isMuted {
            // Unmute: Restore previous volume
            let restored = preMuteVolumes[bundleID] ?? 0.8
            setAppVolume(bundleID: bundleID, volume: restored > 0.05 ? restored : 0.8)
        } else {
            // Mute: Save volume and set to 0
            preMuteVolumes[bundleID] = track.volume
            setAppVolume(bundleID: bundleID, volume: 0.0)
        }
    }
}

private func executeAppleScript(_ source: String) -> String? {
    guard let script = NSAppleScript(source: source) else { return nil }
    var error: NSDictionary?
    let output = script.executeAndReturnError(&error)
    if error != nil { return nil }
    return output.stringValue
}
