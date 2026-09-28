import AppKit
import SwiftUI
import CoreAudio
import AudioToolbox
import CoreGraphics
import Darwin

enum SystemHUDType: String {
    case volume = "Volume"
    case brightness = "Brightness"
}

@MainActor
class SystemHUDManager: ObservableObject {
    static let shared = SystemHUDManager()
    
    @Published var isVisible: Bool = false
    @Published var hudType: SystemHUDType = .volume
    @Published var value: Float = 0.5
    @Published var isMuted: Bool = false
    @Published var isIncreasing: Bool = true
    @Published var sparkleTrigger: Int = 0
    
    private var lastVolume: Float = -1
    private var lastMuted: Bool = false
    private var lastBrightness: Double = -1
    private var isInitialized: Bool = false
    
    private var dismissWorkItem: DispatchWorkItem?
    private var pollTimer: Timer?
    
    typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID) -> Double
    private var getBrightnessFn: GetBrightnessFunc?
    
    init() {
        setupBrightnessFunction()
        
        // Read initial levels without triggering the HUD on launch
        lastVolume = currentVolume()
        lastMuted = currentMuted()
        lastBrightness = currentBrightness()
        isInitialized = true
        
        startMonitoring()
    }
    
    private func setupBrightnessFunction() {
        if let handle = dlopen(nil, RTLD_NOW) {
            if let sym = dlsym(handle, "CoreDisplay_Display_GetUserBrightness") {
                getBrightnessFn = unsafeBitCast(sym, to: GetBrightnessFunc.self)
            }
        }
    }
    
    func startMonitoring() {
        pollTimer?.invalidate()
        // Fast 100ms timer for instant response to keyboard media keys & sliders
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkHardwareChanges()
            }
        }
    }
    
    private func checkHardwareChanges() {
        guard isInitialized else { return }
        
        let newVol = currentVolume()
        let newMuted = currentMuted()
        let newBright = currentBrightness()
        
        // Detect Volume or Mute changes
        if abs(newVol - lastVolume) > 0.005 || newMuted != lastMuted {
            let increasing = newVol > lastVolume
            lastVolume = newVol
            lastMuted = newMuted
            triggerHUD(type: .volume, val: newVol, muted: newMuted, increasing: increasing)
            return
        }
        
        // Detect Brightness changes
        if abs(newBright - lastBrightness) > 0.012 {
            let increasing = newBright > lastBrightness
            lastBrightness = newBright
            triggerHUD(type: .brightness, val: Float(newBright), muted: false, increasing: increasing)
            return
        }
    }
    
    private func triggerHUD(type: SystemHUDType, val: Float, muted: Bool, increasing: Bool) {
        dismissWorkItem?.cancel()
        
        hudType = type
        value = max(0, min(1, val))
        isMuted = muted
        isIncreasing = increasing
        sparkleTrigger &+= 1
        
        AuralHapticsManager.shared.play(.sparkleTick, haptic: .levelChange)
        
        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
            isVisible = true
        }
        
        // Notify window controller to dynamically resize collapsed notch
        NotchWindowController.shared.updateHUDState(visible: true)
        
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.isVisible = false
            }
            NotchWindowController.shared.updateHUDState(visible: false)
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
    
    func currentVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &defaultOutputDeviceID
        )
        guard status == 0 else { return 0.5 }
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol: Float32 = 0.0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        let volStatus = AudioObjectGetPropertyData(defaultOutputDeviceID, &volumeAddress, 0, nil, &volSize, &vol)
        return volStatus == 0 ? vol : 0.5
    }
    
    func currentMuted() -> Bool {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &defaultOutputDeviceID
        )
        guard status == 0 else { return false }
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        let muteStatus = AudioObjectGetPropertyData(defaultOutputDeviceID, &muteAddress, 0, nil, &muteSize, &muted)
        return muteStatus == 0 && muted != 0
    }
    
    func currentBrightness() -> Double {
        if let fn = getBrightnessFn {
            return fn(CGMainDisplayID())
        }
        return 0.8
    }
}
