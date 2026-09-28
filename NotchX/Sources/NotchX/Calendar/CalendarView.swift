import SwiftUI
import AppKit

/// Calendar Tab View embedded inside the expanded notch.
/// Displays today's schedule synced from the macOS Calendar app with meeting join buttons.
struct CalendarView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            if !calendarManager.hasPermission {
                // Permission Request State
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Sync with Mac Calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Show your upcoming meetings and events directly in the notch.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Button(action: {
                        calendarManager.requestPermission()
                    }) {
                        Text("Allow Calendar Access")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if calendarManager.events.isEmpty {
                // Empty Calendar State
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("No Upcoming Events")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Your schedule is completely clear today.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Event Schedule List
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(calendarManager.events) { event in
                            eventCard(event)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func eventCard(_ event: NotchCalendarEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(event.calendarColor)
                    .frame(width: 7, height: 7)
                
                Text(event.timeString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                if let meetURL = event.meetingURL {
                    Button(action: {
                        NSWorkspace.shared.open(meetURL)
                    }) {
                        Text("Join")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Text(event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
            
            if let loc = event.location, !loc.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8))
                    Text(loc)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.55))
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 175, height: 90)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }
}
