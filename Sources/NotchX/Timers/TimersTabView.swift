import SwiftUI
import AppKit

/// Dedicated Notch Buddy-style Timers tab inside NotchX
public struct TimersTabView: View {
    @ObservedObject private var hub = TimerHubManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            // Mode Switcher Pills
            HStack(spacing: 5) {
                ForEach(TimerMode.allCases) { mode in
                    Button(action: {
                        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            hub.currentMode = mode
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 9.5))
                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(hub.currentMode == mode ? .white : .white.opacity(0.55))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            hub.currentMode == mode
                            ? Color.white.opacity(0.18)
                            : Color.white.opacity(0.05)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            
            // Content Card for Selected Mode
            Group {
                switch hub.currentMode {
                case .pomodoro:
                    pomodoroSection
                case .countdown:
                    countdownSection
                case .stopwatch:
                    stopwatchSection
                case .hydration:
                    hydrationSection
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - Pomodoro Mode
    
    private var pomodoroSection: some View {
        HStack(spacing: 16) {
            // Left: Big Digits & Progress Ring
            VStack(alignment: .leading, spacing: 4) {
                // Phase Selector Pills
                HStack(spacing: 4) {
                    phasePill(.focus, label: "25m Focus")
                    phasePill(.shortBreak, label: "5m Break")
                    phasePill(.longBreak, label: "15m Rest")
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(hub.pomodoroTimeString)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(hub.completedSessions) done")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.orange.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18))
                        .clipShape(Capsule())
                }
                
                // Linear Progress Bar
                let frac = hub.pomodoroTotal > 0 ? Double(hub.pomodoroRemaining) / Double(hub.pomodoroTotal) : 0
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.orange)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * frac)), height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Play/Pause and Reset Buttons
            HStack(spacing: 8) {
                Button(action: { hub.togglePomodoro() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 34, height: 34)
                        Image(systemName: hub.isPomodoroRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: hub.isPomodoroRunning ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: { hub.resetPomodoro() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Reset Timer")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }
    
    private func phasePill(_ phase: TimerHubManager.PomodoroPhase, label: String) -> some View {
        Button(action: { hub.setPomodoroPhase(phase) }) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(hub.pomodoroPhase == phase ? .white : .white.opacity(0.55))
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    hub.pomodoroPhase == phase
                    ? Color.orange.opacity(0.75)
                    : Color.white.opacity(0.08)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Countdown Mode
    
    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Preset Capsules
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach([5, 10, 15, 20, 25, 30, 45, 60], id: \.self) { mins in
                        Button(action: { hub.setCountdownMinutes(mins) }) {
                            Text("\(mins)m")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(hub.countdownTotal == mins * 60 ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    hub.countdownTotal == mins * 60
                                    ? Color.blue.opacity(0.8)
                                    : Color.white.opacity(0.08)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            HStack(spacing: 14) {
                Text(hub.countdownTimeString)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { hub.toggleCountdown() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                        Image(systemName: hub.isCountdownRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .offset(x: hub.isCountdownRunning ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: { hub.resetCountdown() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }
    
    // MARK: - Stopwatch Mode
    
    private var stopwatchSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(hub.stopwatchTimeString)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                if let firstLap = hub.laps.first {
                    Text("Lap \(firstLap.lapNumber): \(firstLap.timeString)")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Ready")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 7) {
                if hub.isStopwatchRunning {
                    Button(action: { hub.addLap() }) {
                        Text("Lap")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { hub.toggleStopwatch() }) {
                    ZStack {
                        Circle()
                            .fill(hub.isStopwatchRunning ? Color.red : Color.green)
                            .frame(width: 32, height: 32)
                        Image(systemName: hub.isStopwatchRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: hub.isStopwatchRunning ? 0 : 0.8)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: { hub.resetStopwatch() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }
    
    // MARK: - Hydration Mode
    
    private var hydrationSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: 38, height: 38)
                Image(systemName: "drop.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Hydration Reminder")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Next drink reminder in \(hub.hydrationTimeString)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            Button(action: { hub.takeDrink() }) {
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 10))
                    Text("Drank Water")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }
}
