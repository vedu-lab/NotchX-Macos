// Copyright © 2026 Vedant. All rights reserved.
import AppKit
import SwiftUI
import CoreAudio
import AudioToolbox
import CoreGraphics
import Darwin
import IOKit.hidsystem

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
    private var lastBrightness: Float = -1
    private var isInitialized: Bool = false
    
    private var dismissWorkItem: DispatchWorkItem?
    private var pollTimer: Timer?
    
    // Dynamic PrivateFramework function pointers for DisplayServices
    typealias DSGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias DSSetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    
    private var getBrightnessFn: DSGetBrightnessFunc?
    private var setBrightnessFn: DSSetBrightnessFunc?
    
    init() {
        setupDisplayServices()
        
        // Read initial hardware levels without triggering HUD on app startup
        lastVolume = currentVolume()
        lastMuted = currentMuted()
        lastBrightness = currentBrightness()
        value = lastVolume
        isMuted = lastMuted
        isInitialized = true
        
        // Start background polling and event interception
        startMonitoring()
        MediaKeyInterceptor.shared.start()
    }
    
    private func setupDisplayServices() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) {
            if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightnessFn = unsafeBitCast(getSym, to: DSGetBrightnessFunc.self)
            }
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessFn = unsafeBitCast(setSym, to: DSSetBrightnessFunc.self)
            }
        }
    }
    
    func startMonitoring() {
        pollTimer?.invalidate()
        setupAudioListeners()
        
        // Relaxed 1.2s check for external brightness changes (keyboard brightness uses direct 0ms interceptor)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkBrightnessChanges()
            }
        }
    }
    
    private func setupAudioListeners() {
        let devID = getDefaultOutputDeviceID()
        guard devID != 0 else { return }
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Listen for volume changes event-driven (0% polling overhead)
        AudioObjectAddPropertyListenerBlock(devID, &volumeAddress, DispatchQueue.main) { [weak self] _, _ in
            Task { @MainActor in
                self?.handleHardwareVolumeChanged()
            }
        }
        
        // Listen for mute changes
        AudioObjectAddPropertyListenerBlock(devID, &muteAddress, DispatchQueue.main) { [weak self] _, _ in
            Task { @MainActor in
                self?.handleHardwareVolumeChanged()
            }
        }
        
        // Listen for default output device changes
        var devAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devAddress, DispatchQueue.main) { [weak self] _, _ in
            Task { @MainActor in
                self?.setupAudioListeners()
                self?.handleHardwareVolumeChanged()
            }
        }
    }
    
    private func handleHardwareVolumeChanged() {
        guard isInitialized else { return }
        let newVol = currentVolume()
        let newMuted = currentMuted()
        
        if abs(newVol - lastVolume) > 0.005 || newMuted != lastMuted {
            let increasing = newVol > lastVolume
            lastVolume = newVol
            lastMuted = newMuted
            triggerHUD(type: .volume, val: newVol, muted: newMuted, increasing: increasing)
        }
    }
    
    private func checkBrightnessChanges() {
        guard isInitialized else { return }
        let newBright = currentBrightness()
        if abs(newBright - lastBrightness) > 0.008 {
            let increasing = newBright > lastBrightness
            lastBrightness = newBright
            triggerHUD(type: .brightness, val: newBright, muted: false, increasing: increasing)
        }
    }
    
    /// Called directly by MediaKeyInterceptor when a volume or brightness key is pressed.
    /// Handles the adjustment and shows the HUD immediately while suppressing native macOS OSD.
    public func handleMediaKey(keyCode: Int32, isFine: Bool) {
        let step: Float = isFine ? (1.0 / 64.0) : (1.0 / 16.0)
        
        switch keyCode {
        case NX_KEYTYPE_SOUND_UP:
            if currentMuted() {
                setSystemMuted(false)
            }
            let cur = currentVolume()
            let newVol = min(1.0, cur + step)
            setSystemVolume(newVol)
            triggerHUD(type: .volume, val: newVol, muted: false, increasing: true)
            
        case NX_KEYTYPE_SOUND_DOWN:
            let cur = currentVolume()
            let newVol = max(0.0, cur - step)
            setSystemVolume(newVol)
            triggerHUD(type: .volume, val: newVol, muted: newVol <= 0.001, increasing: false)
            
        case NX_KEYTYPE_MUTE:
            let newMuted = !currentMuted()
            setSystemMuted(newMuted)
            triggerHUD(type: .volume, val: currentVolume(), muted: newMuted, increasing: false)
            
        case NX_KEYTYPE_BRIGHTNESS_UP:
            let cur = currentBrightness()
            let newBright = min(1.0, cur + step)
            setSystemBrightness(newBright)
            triggerHUD(type: .brightness, val: newBright, muted: false, increasing: true)
            
        case NX_KEYTYPE_BRIGHTNESS_DOWN:
            let cur = currentBrightness()
            let newBright = max(0.0, cur - step)
            setSystemBrightness(newBright)
            triggerHUD(type: .brightness, val: newBright, muted: false, increasing: false)
            
        default:
            break
        }
    }
    
    public func triggerHUD(type: SystemHUDType, val: Float, muted: Bool, increasing: Bool) {
        dismissWorkItem?.cancel()
        
        hudType = type
        value = max(0, min(1, val))
        isMuted = muted
        isIncreasing = increasing
        sparkleTrigger &+= 1
        
        // Kept silent as requested (no audio or haptic playback during volume/brightness changes)
        withAnimation(.spring(response: 0.20, dampingFraction: 0.75)) {
            isVisible = true
        }
        
        // Notify window controller to dynamically resize collapsed notch
        NotchWindowController.shared.updateHUDState(visible: true)
        
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                self.isVisible = false
            }
            NotchWindowController.shared.updateHUDState(visible: false)
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
    
    // MARK: - Hardware Getters & Setters
    
    private func getDefaultOutputDeviceID() -> AudioDeviceID {
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
        return status == 0 ? defaultOutputDeviceID : 0
    }
    
    func currentVolume() -> Float {
        let devID = getDefaultOutputDeviceID()
        guard devID != 0 else { return 0.5 }
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol: Float32 = 0.0
        var volSize = UInt32(MemoryLayout<Float32>.size)
        let volStatus = AudioObjectGetPropertyData(devID, &volumeAddress, 0, nil, &volSize, &vol)
        return volStatus == 0 ? vol : 0.5
    }
    
    func setSystemVolume(_ volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        let devID = getDefaultOutputDeviceID()
        guard devID != 0 else { return }
        
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol = clamped
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(devID, &volumeAddress, 0, nil, size, &vol)
        lastVolume = clamped
    }
    
    func currentMuted() -> Bool {
        let devID = getDefaultOutputDeviceID()
        guard devID != 0 else { return false }
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        let muteStatus = AudioObjectGetPropertyData(devID, &muteAddress, 0, nil, &muteSize, &muted)
        return muteStatus == 0 && muted != 0
    }
    
    func setSystemMuted(_ muted: Bool) {
        let devID = getDefaultOutputDeviceID()
        guard devID != 0 else { return }
        
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var val: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(devID, &muteAddress, 0, nil, size, &val)
        lastMuted = muted
    }
    
    func currentBrightness() -> Float {
        if let fn = getBrightnessFn {
            var b: Float = 0.5
            let status = fn(CGMainDisplayID(), &b)
            if status == 0 {
                return b
            }
        }
        return 0.5
    }
    
    func setSystemBrightness(_ brightness: Float) {
        let clamped = max(0.0, min(1.0, brightness))
        if let fn = setBrightnessFn {
            _ = fn(CGMainDisplayID(), clamped)
        }
        lastBrightness = clamped
    }
}
