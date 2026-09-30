import Foundation
import Combine

/// Lightweight, 60fps Pomodoro & Countdown timer for NotchX quick status capsule
public class TimerManager: ObservableObject {
    public static let shared = TimerManager()
    
    @Published public var isRunning: Bool = false
    @Published public var totalSeconds: Int = 25 * 60
    @Published public var remainingSeconds: Int = 25 * 60
    
    private var timer: Timer?
    
    private init() {}
    
    public var formattedTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        if isRunning {
            return String(format: "%02d:%02d", mins, secs)
        } else {
            return "\(mins) min"
        }
    }
    
    public func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }
    
    public func start() {
        if remainingSeconds <= 0 {
            remainingSeconds = totalSeconds
        }
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
            } else {
                self.pause()
                AuralHapticsManager.shared.play(.completionChime, haptic: .levelChange)
            }
        }
    }
    
    public func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    public func reset(minutes: Int = 25) {
        pause()
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
    }
}
