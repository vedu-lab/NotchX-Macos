import SwiftUI
import AppKit

/// Sleek 21-day horizontal calendar week strip with large month typography,
/// smooth left/right scrolling, and upcoming event indicators matching the NotchX HUD aesthetic.
struct CalendarStripView: View {
    var isCompact: Bool = false
    @ObservedObject private var calendarManager = CalendarManager.shared
    
    // 21 days: 7 days in the past, today (0), and 13 days in the future
    private let dayOffsets: [Int] = Array(-7...13)
    
    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 3.5 : 5) {
            // Row 1: Month Name + 21-Day Horizontal Scrollable Strip
            HStack(alignment: .center, spacing: isCompact ? 6 : 8) {
                // Bold Month Name (e.g. "SEP", "OCT")
                Text(currentMonthString().uppercased())
                    .font(.system(size: isCompact ? 13 : 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: isCompact ? 28 : 34, alignment: .leading)
                
                // 21-Day Horizontal Scrollable Strip
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: isCompact ? 4 : 5) {
                            ForEach(dayOffsets, id: \.self) { offset in
                                dayCell(offset: offset)
                                    .id(offset)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo(0, anchor: .center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Row 2: Event Preview or "Nothing for today"
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: isCompact ? 8.5 : 9.5))
                    .foregroundColor(.white.opacity(0.50))
                
                if let nextEvent = calendarManager.events.first(where: { $0.isUpcoming }) {
                    Text("\(nextEvent.title) (\(nextEvent.timeString))")
                        .font(.system(size: isCompact ? 8.5 : 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                    
                    if let meetURL = nextEvent.meetingURL {
                        Button(action: {
                            NSWorkspace.shared.open(meetURL)
                        }) {
                            Text("Join")
                                .font(.system(size: isCompact ? 7.5 : 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Nothing for today")
                        .font(.system(size: isCompact ? 8.5 : 9.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
    }
    
    // MARK: - Day Cell
    
    private func dayCell(offset: Int) -> some View {
        let cal = Calendar.current
        let today = Date()
        let date = cal.date(byAdding: .day, value: offset, to: today) ?? today
        let isToday = (offset == 0)
        let isWeekend = cal.isDateInWeekend(date)
        
        let dayNum = String(format: "%02d", cal.component(.day, from: date))
        
        let weekdayLabel: String = {
            if isToday {
                let fmt = DateFormatter()
                fmt.dateFormat = "EEE"
                return fmt.string(from: date).uppercased() // e.g. "WED"
            } else {
                let fmt = DateFormatter()
                fmt.dateFormat = "EEEEE" // Single letter: "M", "T", "W", "T", "F", "S", "S"
                return fmt.string(from: date).uppercased()
            }
        }()
        
        return VStack(spacing: 1.5) {
            // Weekday letter or "WED"
            Text(weekdayLabel)
                .font(.system(size: isCompact ? 6.5 : 7.5, weight: isToday ? .bold : .semibold))
                .foregroundColor(
                    isToday
                    ? Color(red: 0.35, green: 0.70, blue: 1.0)
                    : Color.white.opacity(0.35)
                )
            
            // 2-digit Day Number
            Text(dayNum)
                .font(.system(size: isCompact ? 8.5 : 9.5, weight: isToday ? .bold : .medium, design: .monospaced))
                .foregroundColor(
                    isToday
                    ? Color(red: 0.35, green: 0.70, blue: 1.0)
                    : (isWeekend ? Color.red.opacity(0.70) : Color.white.opacity(0.55))
                )
                .padding(.horizontal, isToday ? (isCompact ? 3.5 : 4.5) : 1.5)
                .padding(.vertical, isToday ? 1 : 0)
                .background(
                    isToday
                    ? Color.blue.opacity(0.25)
                    : Color.clear
                )
                .clipShape(Capsule())
                .overlay(
                    isToday
                    ? Capsule().stroke(Color.blue.opacity(0.6), lineWidth: 0.7)
                    : nil
                )
        }
        .frame(minWidth: isToday ? (isCompact ? 22 : 25) : (isCompact ? 13 : 15))
    }
    
    private func currentMonthString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt.string(from: Date())
    }
}

/// Full-profile Calendar Tab View for NotchX
public struct FullCalendarTabView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header with Open Calendar button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                    Text("CALENDAR & AGENDA")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.6)
                }
                
                Spacer()
                
                Button(action: {
                    if let url = URL(string: "calshow:") {
                        NSWorkspace.shared.open(url)
                    }
                    AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 9))
                        Text("Open Calendar")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            
            // 21-Day Strip Card
            CalendarStripView(isCompact: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                        )
                )
                .padding(.horizontal, 16)
            
            // Upcoming Events List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    if calendarManager.events.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                            Text("No upcoming events today")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    } else {
                        ForEach(calendarManager.events.prefix(3), id: \.id) { event in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(event.isUpcoming ? Color.blue : Color.gray)
                                    .frame(width: 6, height: 6)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(event.timeString)
                                        .font(.system(size: 8.5))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                
                                Spacer()
                                
                                if let url = event.meetingURL {
                                    Button(action: {
                                        NSWorkspace.shared.open(url)
                                    }) {
                                        Text("Join")
                                            .font(.system(size: 8.5, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Color.blue)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

