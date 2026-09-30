// Copyright © 2026 Vedant. All rights reserved.
import Cocoa
import CoreGraphics
import IOKit.hidsystem

/// Intercepts system media keys (Volume Up, Volume Down, Mute, Brightness Up, Brightness Down)
/// via a low-level CGEventTap and swallows them so the native macOS On-Screen Display (OSD) bezel
/// NEVER appears. Simultaneously routes the action directly to NotchX SystemHUDManager.
@MainActor
public class MediaKeyInterceptor {
    public static let shared = MediaKeyInterceptor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning: Bool = false
    private var retryTimer: Timer?
    
    private init() {}
    
    /// Check whether macOS Accessibility permissions are granted
    public var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }
    
    /// Request Accessibility permission from macOS with system prompt
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    /// Start intercepting media keys if allowed by settings and permissions
    public func start() {
        guard SettingsManager.shared.suppressNativeOSD else { return }
        guard !isRunning else { return }
        guard AXIsProcessTrusted() else {
            // Permission not granted yet — schedule periodic background check
            if retryTimer == nil {
                retryTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        if AXIsProcessTrusted() {
                            self?.retryTimer?.invalidate()
                            self?.retryTimer = nil
                            self?.start()
                        }
                    }
                }
            }
            return
        }
        
        retryTimer?.invalidate()
        retryTimer = nil
        
        let mask = (1 << 14) // NX_SYSDEFINED (system-defined events like media keys)
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            // Re-enable tap if disabled by timeout
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon = refcon {
                    let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                    interceptor.reEnableTap()
                }
                return Unmanaged.passRetained(event)
            }
            
            // Check for NX_SYSDEFINED (14)
            if type.rawValue == 14 {
                if let nsEvent = NSEvent(cgEvent: event), nsEvent.type == .systemDefined && nsEvent.subtype.rawValue == 8 {
                    let data1 = nsEvent.data1
                    let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
                    let keyFlags = data1 & 0x0000FFFF
                    let keyState = (keyFlags & 0xFF00) >> 8
                    let isKeyDown = (keyState == 0xA || keyState == 0x1)
                    
                    switch keyCode {
                    case NX_KEYTYPE_SOUND_UP,
                         NX_KEYTYPE_SOUND_DOWN,
                         NX_KEYTYPE_MUTE,
                         NX_KEYTYPE_BRIGHTNESS_UP,
                         NX_KEYTYPE_BRIGHTNESS_DOWN:
                        
                        if isKeyDown {
                            let isFine = nsEvent.modifierFlags.contains(.shift) && nsEvent.modifierFlags.contains(.option)
                            Task { @MainActor in
                                SystemHUDManager.shared.handleMediaKey(keyCode: keyCode, isFine: isFine)
                            }
                        }
                        
                        // SWALLOW the event! Returning nil prevents macOS's OSDUIHelper from ever seeing it,
                        // completely suppressing the default square translucent volume & brightness HUD.
                        return nil
                        
                    default:
                        break
                    }
                }
            }
            
            return Unmanaged.passRetained(event)
        }
        
        // Create the event tap at the session level
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }
        
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        self.eventTap = tap
        self.runLoopSource = source
        self.isRunning = true
    }
    
    public func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        guard isRunning else { return }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
    }
    
    fileprivate func reEnableTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}
