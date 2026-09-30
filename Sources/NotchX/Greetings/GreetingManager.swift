// Copyright © 2026 Vedant. All rights reserved.
import SwiftUI
import AppKit

/// Manages the iconic Apple "hello." launch greeting and permanent notch greetings
@MainActor
public class GreetingManager: ObservableObject {
    public static let shared = GreetingManager()
    
    @Published public var isGreetingActive: Bool = false
    @Published public var isAppLaunch: Bool = false
    @Published public var strokeAnimationTrigger: Int = 0
    
    public var currentWord: String {
        SettingsManager.shared.greetingText.isEmpty ? "hello." : SettingsManager.shared.greetingText
    }
    
    private var dismissTimer: DispatchWorkItem?
    
    private init() {}
    
    /// Triggers the full Apple "hello." hero greeting animation once when NotchX launches
    public func triggerLaunchGreeting() {
        guard SettingsManager.shared.greetingOnLaunchEnabled else { return }
        
        dismissTimer?.cancel()
        
        isAppLaunch = true
        strokeAnimationTrigger &+= 1
        
        AuralHapticsManager.shared.play(.completionChime, haptic: .levelChange)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            isGreetingActive = true
        }
        
        NotchWindowController.shared.updateFloatingBannerState()
        
        // Auto-dismiss the large pop-up after 3.8s with smooth spring retraction
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.dismissGreeting()
        }
        dismissTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8, execute: work)
    }
    
    /// Replays the Apple "hello." cursive flourish when user clicks the greeting badge
    public func replayGreeting() {
        dismissTimer?.cancel()
        
        isAppLaunch = false
        strokeAnimationTrigger &+= 1
        
        AuralHapticsManager.shared.play(.sparkleTick, haptic: .alignment)
        
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            isGreetingActive = true
        }
        
        NotchWindowController.shared.updateFloatingBannerState()
        
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.dismissGreeting()
        }
        dismissTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: work)
    }
    
    public func dismissGreeting() {
        dismissTimer?.cancel()
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isGreetingActive = false
            isAppLaunch = false
        }
        
        NotchWindowController.shared.updateFloatingBannerState()
    }
}
