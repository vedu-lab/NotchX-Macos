import Foundation
import Combine
import AppKit

public enum TimerMode: String, CaseIterable, Identifiable {
    case pomodoro = "Pomodoro"
    case countdown = "Countdown"
    case stopwatch = "Stopwatch"
    case hydration = "Hydration"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .pomodoro: return "brain.head.profile"
        case .countdown: return "timer"
        case .stopwatch: return "stopwatch"
        case .hydration: return "drop.fill"
        }
    }
}

public struct StopwatchLap: Identifiable, Equatable {
    public let id = UUID()
    public let lapNumber: Int
    public let timeString: String
}

/// Central multi-mode timer engine for NotchX Timers tab
public class TimerHubManager: ObservableObject {
    public static let shared = TimerHubManager()
    
    @Published public var currentMode: TimerMode = .pomodoro
    
    // --- Pomodoro ---
    public enum PomodoroPhase: String {
        case focus = "Focus"
        case shortBreak = "Short Break"
        case longBreak = "Long Break"
        
        public var defaultMinutes: Int {
            switch self {
            case .focus: return 25
            case .shortBreak: return 5
            case .longBreak: return 15
            }
        }
    }
    
    @Published public var pomodoroPhase: PomodoroPhase = .focus
    @Published public var pomodoroRemaining: Int = 25 * 60
    @Published public var pomodoroTotal: Int = 25 * 60
    @Published public var isPomodoroRunning: Bool = false
    @Published public var completedSessions: Int = 0
    private var pomodoroTimer: Timer?
    
    // --- Countdown ---
    @Published public var countdownRemaining: Int = 10 * 60
    @Published public var countdownTotal: Int = 10 * 60
    @Published public var isCountdownRunning: Bool = false
    private var countdownTimer: Timer?
    
    // --- Stopwatch ---
    @Published public var stopwatchMilliseconds: Int = 0
    @Published public var isStopwatchRunning: Bool = false
    @Published public var laps: [StopwatchLap] = []
    private var stopwatchTimer: Timer?
    
    // --- Hydration Reminder ---
    @Published public var isHydrationActive: Bool = true
    @Published public var hydrationIntervalMinutes: Int = 45
    @Published public var hydrationSecondsRemaining: Int = 45 * 60
    private var hydrationTimer: Timer?
    
    private init() {
        startHydrationMonitor()
    }
    
    // MARK: - Pomodoro Logic
    
    public func setPomodoroPhase(_ phase: PomodoroPhase) {
        pomodoroTimer?.invalidate()
        isPomodoroRunning = false
        pomodoroPhase = phase
        pomodoroTotal = phase.defaultMinutes * 60
        pomodoroRemaining = pomodoroTotal
        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
    }
    
    public func togglePomodoro() {
        if isPomodoroRunning {
            pausePomodoro()
        } else {
            startPomodoro()
        }
    }
    
    public func startPomodoro() {
        isPomodoroRunning = true
        pomodoroTimer?.invalidate()
        AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
        
        pomodoroTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.pomodoroRemaining > 0 {
                self.pomodoroRemaining -= 1
            } else {
                self.finishPomodoro()
            }
        }
    }
    
    public func pausePomodoro() {
        isPomodoroRunning = false
        pomodoroTimer?.invalidate()
        pomodoroTimer = nil
        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
    }
    
    public func resetPomodoro() {
        pausePomodoro()
        pomodoroRemaining = pomodoroTotal
    }
    
    private func finishPomodoro() {
        pausePomodoro()
        if pomodoroPhase == .focus {
            completedSessions += 1
            setPomodoroPhase(completedSessions % 4 == 0 ? .longBreak : .shortBreak)
        } else {
            setPomodoroPhase(.focus)
        }
        AuralHapticsManager.shared.play(.completionChime, haptic: .levelChange)
    }
    
    public var pomodoroTimeString: String {
        let mins = pomodoroRemaining / 60
        let secs = pomodoroRemaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Countdown Logic
    
    public func setCountdownMinutes(_ minutes: Int) {
        countdownTimer?.invalidate()
        isCountdownRunning = false
        countdownTotal = minutes * 60
        countdownRemaining = countdownTotal
        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
    }
    
    public func toggleCountdown() {
        if isCountdownRunning {
            pauseCountdown()
        } else {
            startCountdown()
        }
    }
    
    public func startCountdown() {
        isCountdownRunning = true
        countdownTimer?.invalidate()
        AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.countdownRemaining > 0 {
                self.countdownRemaining -= 1
            } else {
                self.pauseCountdown()
                AuralHapticsManager.shared.play(.completionChime, haptic: .levelChange)
            }
        }
    }
    
    public func pauseCountdown() {
        isCountdownRunning = false
        countdownTimer?.invalidate()
        countdownTimer = nil
        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
    }
    
    public func resetCountdown() {
        pauseCountdown()
        countdownRemaining = countdownTotal
    }
    
    public var countdownTimeString: String {
        let mins = countdownRemaining / 60
        let secs = countdownRemaining % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Stopwatch Logic
    
    public func toggleStopwatch() {
        if isStopwatchRunning {
            pauseStopwatch()
        } else {
            startStopwatch()
        }
    }
    
    public func startStopwatch() {
        isStopwatchRunning = true
        stopwatchTimer?.invalidate()
        AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
        
        let start = Date().timeIntervalSinceReferenceDate - Double(stopwatchMilliseconds) / 100.0
        stopwatchTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date().timeIntervalSinceReferenceDate
            self.stopwatchMilliseconds = Int((now - start) * 100)
        }
    }
    
    public func pauseStopwatch() {
        isStopwatchRunning = false
        stopwatchTimer?.invalidate()
        stopwatchTimer = nil
        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
    }
    
    public func resetStopwatch() {
        pauseStopwatch()
        stopwatchMilliseconds = 0
        laps.removeAll()
    }
    
    public func addLap() {
        let lapNum = laps.count + 1
        laps.insert(StopwatchLap(lapNumber: lapNum, timeString: stopwatchTimeString), at: 0)
        AuralHapticsManager.shared.play(.sparkleTick, haptic: .generic)
    }
    
    public var stopwatchTimeString: String {
        let totalSeconds = stopwatchMilliseconds / 100
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        let hundredths = stopwatchMilliseconds % 100
        return String(format: "%02d:%02d.%02d", mins, secs, hundredths)
    }
    
    // MARK: - Hydration Logic
    
    private func startHydrationMonitor() {
        hydrationTimer?.invalidate()
        hydrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isHydrationActive else { return }
            if self.hydrationSecondsRemaining > 0 {
                self.hydrationSecondsRemaining -= 1
            } else {
                self.hydrationSecondsRemaining = self.hydrationIntervalMinutes * 60
                AuralHapticsManager.shared.play(.completionChime, haptic: .levelChange)
            }
        }
    }
    
    public func takeDrink() {
        hydrationSecondsRemaining = hydrationIntervalMinutes * 60
        AuralHapticsManager.shared.play(.sparkleTick, haptic: .generic)
    }
    
    public var hydrationTimeString: String {
        let mins = hydrationSecondsRemaining / 60
        return "\(mins)m"
    }
}
