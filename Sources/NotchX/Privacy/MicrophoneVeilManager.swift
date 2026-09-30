import Foundation
import AppKit
import CoreAudio
import AudioToolbox
import Combine

/// Manages the Microphone Privacy Veil & Global Hardware Kill Switch.
/// - Actively detects if any hardware stream is drawing audio from the microphone
/// - Provides a global 1-click Hardware Kill Switch that drops input volume to 0%
///   and engages hardware device mute
public class MicrophoneVeilManager: ObservableObject {
    public static let shared = MicrophoneVeilManager()
    
    @Published public var isMicStreaming: Bool = false
    @Published public var isKillSwitchActive: Bool = false
    @Published public var currentInputVolume: Double = 1.0
    
    private var previousVolume: Double = 1.0
    private var pollTimer: Timer?
    private let queue = DispatchQueue(label: "com.notchx.micveil", qos: .userInitiated)
    
    private init() {
        checkHardwareState()
        setupAudioListeners()
        // Relaxed 5.0s safety fallback check (real-time changes handled event-driven by CoreAudio property listeners)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkHardwareState()
        }
    }
    
    private func setupAudioListeners() {
        let inputDeviceID = getDefaultInputDeviceID()
        guard inputDeviceID != 0 else { return }
        
        var isRunningProp = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var volProp = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muteProp = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(inputDeviceID, &isRunningProp, DispatchQueue.main) { [weak self] _, _ in
            self?.checkHardwareState()
        }
        AudioObjectAddPropertyListenerBlock(inputDeviceID, &volProp, DispatchQueue.main) { [weak self] _, _ in
            self?.checkHardwareState()
        }
        AudioObjectAddPropertyListenerBlock(inputDeviceID, &muteProp, DispatchQueue.main) { [weak self] _, _ in
            self?.checkHardwareState()
        }
        
        // Listen for default input device changes
        var devAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.setupAudioListeners()
            self?.checkHardwareState()
        }
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    public func checkHardwareState() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var inputDeviceID = AudioDeviceID(0)
            var prop = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &prop,
                0,
                nil,
                &size,
                &inputDeviceID
            )
            
            guard status == noErr, inputDeviceID != 0 else { return }
            
            // 1. Check if microphone is running somewhere
            var isRunning: UInt32 = 0
            var runProp = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var runSize = UInt32(MemoryLayout<UInt32>.size)
            let runStatus = AudioObjectGetPropertyData(inputDeviceID, &runProp, 0, nil, &runSize, &isRunning)
            let active = (runStatus == noErr && isRunning != 0)
            
            // 2. Check current input volume level
            var volume: Float32 = 1.0
            var volProp = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var volSize = UInt32(MemoryLayout<Float32>.size)
            let volStatus = AudioObjectGetPropertyData(inputDeviceID, &volProp, 0, nil, &volSize, &volume)
            
            // 3. Check hardware mute
            var isMuted: UInt32 = 0
            var muteProp = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var muteSize = UInt32(MemoryLayout<UInt32>.size)
            _ = AudioObjectGetPropertyData(inputDeviceID, &muteProp, 0, nil, &muteSize, &isMuted)
            
            let isKilled = (volStatus == noErr && volume <= 0.01) || (isMuted != 0)
            
            DispatchQueue.main.async {
                self.isMicStreaming = active && !isKilled
                self.isKillSwitchActive = isKilled
                if volStatus == noErr {
                    self.currentInputVolume = Double(volume)
                }
            }
        }
    }
    
    /// Global Kill Switch: Mechanically drops microphone input volume to 0% and engages hardware mute
    public func toggleKillSwitch() {
        if isKillSwitchActive {
            disengageKillSwitch()
        } else {
            engageKillSwitch()
        }
    }
    
    public func engageKillSwitch() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Save current volume before killing
            if self.currentInputVolume > 0.05 {
                self.previousVolume = self.currentInputVolume
            } else {
                self.previousVolume = 1.0
            }
            
            let inputDeviceID = self.getDefaultInputDeviceID()
            if inputDeviceID != 0 {
                // 1. Hardware volume to 0.0
                var zeroVol: Float32 = 0.0
                var volProp = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                let volSize = UInt32(MemoryLayout<Float32>.size)
                _ = AudioObjectSetPropertyData(inputDeviceID, &volProp, 0, nil, volSize, &zeroVol)
                
                // 2. Hardware mute to 1
                var muteVal: UInt32 = 1
                var muteProp = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                let muteSize = UInt32(MemoryLayout<UInt32>.size)
                _ = AudioObjectSetPropertyData(inputDeviceID, &muteProp, 0, nil, muteSize, &muteVal)
            }
            
            // 3. AppleScript input volume 0
            _ = executeAppleScript("set volume input volume 0")
            
            // 4. Meeting app mute triggers
            self.muteAllMeetingApps()
            
            // Haptic click & mechanical sound
            DispatchQueue.main.async {
                AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
                self.isKillSwitchActive = true
                self.isMicStreaming = false
                self.currentInputVolume = 0.0
            }
        }
    }
    
    public func disengageKillSwitch() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let restoreVol = Float32(self.previousVolume > 0.05 ? self.previousVolume : 1.0)
            let inputDeviceID = self.getDefaultInputDeviceID()
            
            if inputDeviceID != 0 {
                // 1. Hardware unmute
                var unmuteVal: UInt32 = 0
                var muteProp = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                let muteSize = UInt32(MemoryLayout<UInt32>.size)
                _ = AudioObjectSetPropertyData(inputDeviceID, &muteProp, 0, nil, muteSize, &unmuteVal)
                
                // 2. Hardware volume restore
                var targetVol = restoreVol
                var volProp = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeInput,
                    mElement: kAudioObjectPropertyElementMain
                )
                let volSize = UInt32(MemoryLayout<Float32>.size)
                _ = AudioObjectSetPropertyData(inputDeviceID, &volProp, 0, nil, volSize, &targetVol)
            }
            
            let intVol = Int(restoreVol * 100)
            _ = executeAppleScript("set volume input volume \(intVol)")
            
            DispatchQueue.main.async {
                AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
                self.isKillSwitchActive = false
                self.currentInputVolume = Double(restoreVol)
                self.checkHardwareState()
            }
        }
    }
    
    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var inputDeviceID = AudioDeviceID(0)
        var prop = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &prop,
            0,
            nil,
            &size,
            &inputDeviceID
        )
        return status == noErr ? inputDeviceID : 0
    }
    
    private func muteAllMeetingApps() {
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            guard let bundleID = app.bundleIdentifier else { continue }
            if bundleID.contains("zoom.us") {
                _ = executeAppleScript("tell application \"System Events\" to tell process \"zoom.us\" to keystroke \"a\" using {command down, shift down}")
            } else if bundleID == "com.apple.FaceTime" {
                _ = executeAppleScript("tell application \"System Events\" to tell process \"FaceTime\" to keystroke \"m\" using {command down, shift down}")
            }
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
