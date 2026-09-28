import SwiftUI
import AppKit

/// Sleek 21-day horizontal calendar week strip with large month typography,
/// smooth left/right scrolling, and upcoming event indicators matching the NotchX HUD aesthetic.
struct CalendarStripView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    
    // 21 days: 7 days in the past, today (0), and 13 days in the future
    private let dayOffsets: [Int] = Array(-7...13)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Month Name + 21-Day Horizontal Scrollable Strip
            HStack(alignment: .center, spacing: 10) {
                // Large Bold Month Name (e.g. "Sep", "Oct")
                Text(currentMonthString())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 42, alignment: .leading)
                
                // 21-Day Horizontal Scrollable Strip
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(dayOffsets, id: \.self) { offset in
                                dayCell(offset: offset)
                                    .id(offset)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
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
            HStack(spacing: 5) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.45))
                
                if let nextEvent = calendarManager.events.first(where: { $0.isUpcoming }) {
                    Text("\(nextEvent.title) (\(nextEvent.timeString))")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    if let meetURL = nextEvent.meetingURL {
                        Button(action: {
                            NSWorkspace.shared.open(meetURL)
                        }) {
                            Text("Join")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Nothing for today")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .padding(.top, 1)
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
                return fmt.string(from: date).uppercased() // e.g. "MON"
            } else {
                let fmt = DateFormatter()
                fmt.dateFormat = "EEEEE" // Single letter: "M", "T", "W", "T", "F", "S", "S"
                return fmt.string(from: date).uppercased()
            }
        }()
        
        return VStack(spacing: 2) {
            // Weekday letter or "MON"
            Text(weekdayLabel)
                .font(.system(size: 8, weight: isToday ? .bold : .semibold))
                .foregroundColor(
                    isToday
                    ? Color(red: 0.22, green: 0.58, blue: 1.0)
                    : Color.white.opacity(0.35)
                )
            
            // 2-digit Day Number
            Text(dayNum)
                .font(.system(size: 10.5, weight: isToday ? .bold : .medium, design: .monospaced))
                .foregroundColor(
                    isToday
                    ? Color(red: 0.22, green: 0.58, blue: 1.0)
                    : (isWeekend ? Color.red.opacity(0.65) : Color.white.opacity(0.50))
                )
                .padding(.horizontal, isToday ? 5 : 2)
                .padding(.vertical, isToday ? 1.5 : 0)
                .background(
                    isToday
                    ? Color.blue.opacity(0.20)
                    : Color.clear
                )
                .clipShape(Capsule())
                .overlay(
                    isToday
                    ? Capsule().stroke(Color.blue.opacity(0.5), lineWidth: 0.8)
                    : nil
                )
        }
        .frame(minWidth: isToday ? 28 : 16)
    }
    
    private func currentMonthString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return fmt.string(from: Date())
    }
}
