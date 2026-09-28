import Foundation
import EventKit
import SwiftUI
import Combine

/// A calendar event synced from macOS native Calendar app
struct NotchCalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: Color
    let location: String?
    let meetingURL: URL?
    
    var timeString: String {
        if isAllDay { return "All Day" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
    
    var isUpcoming: Bool {
        endDate > Date()
    }
}

/// Manager linking NotchX to the user's macOS Calendar via EventKit
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    @Published var events: [NotchCalendarEvent] = []
    @Published var hasPermission: Bool = false
    @Published var permissionRequested: Bool = false
    
    private let eventStore = EKEventStore()
    
    private init() {
        checkPermission()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarStoreChanged),
            name: .EKEventStoreChanged,
            object: nil
        )
    }
    
    func checkPermission() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            hasPermission = (status == .fullAccess)
        } else {
            hasPermission = (status == .authorized)
        }
        
        if hasPermission {
            fetchTodayEvents()
        }
    }
    
    func requestPermission() {
        permissionRequested = true
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    if granted {
                        self?.fetchTodayEvents()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    if granted {
                        self?.fetchTodayEvents()
                    }
                }
            }
        }
    }
    
    func fetchTodayEvents() {
        let now = Date()
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        guard let endOfDay = cal.date(byAdding: .day, value: 2, to: startOfDay) else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let rawEvents = eventStore.events(matching: predicate)
        
        let mapped = rawEvents
            .sorted { $0.startDate < $1.startDate }
            .map { ekEvent -> NotchCalendarEvent in
                let color = Color(nsColor: ekEvent.calendar.color)
                
                // Detect Zoom / Google Meet / Teams link in notes or URL
                var meetURL: URL? = ekEvent.url
                if meetURL == nil, let notes = ekEvent.notes {
                    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                    let matches = detector?.matches(in: notes, options: [], range: NSRange(location: 0, length: notes.utf16.count))
                    for match in matches ?? [] {
                        if let matchUrl = match.url,
                           (matchUrl.host?.contains("zoom.us") == true ||
                            matchUrl.host?.contains("meet.google.com") == true ||
                            matchUrl.host?.contains("teams.microsoft.com") == true) {
                            meetURL = matchUrl
                            break
                        }
                    }
                }
                
                return NotchCalendarEvent(
                    id: ekEvent.eventIdentifier ?? UUID().uuidString,
                    title: ekEvent.title ?? "Untitled Event",
                    startDate: ekEvent.startDate,
                    endDate: ekEvent.endDate,
                    isAllDay: ekEvent.isAllDay,
                    calendarColor: color,
                    location: ekEvent.location,
                    meetingURL: meetURL
                )
            }
        
        DispatchQueue.main.async {
            self.events = mapped
        }
    }
    
    @objc private func calendarStoreChanged() {
        if hasPermission {
            fetchTodayEvents()
        }
    }
}
