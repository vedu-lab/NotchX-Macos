// Copyright © 2026 Vedant. All rights reserved.
import Foundation
import SwiftUI

/// Notification category classification
public enum NotificationCategory: String, Codable, CaseIterable, Sendable {
    case system = "System"
    case messages = "Messages"
    case calendar = "Calendar"
    case media = "Media"
    case general = "General"
    
    public var iconName: String {
        switch self {
        case .system: return "gearshape.fill"
        case .messages: return "message.fill"
        case .calendar: return "calendar.badge.clock"
        case .media: return "music.note"
        case .general: return "bell.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .system: return .purple
        case .messages: return .green
        case .calendar: return .red
        case .media: return .pink
        case .general: return .blue
        }
    }
}

/// Represents an individual notification item in NotchX
public struct NotificationItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var message: String
    public var category: NotificationCategory
    public var iconName: String
    public var colorHex: String
    public var sourceApp: String
    public var timestamp: Date
    public var isRead: Bool
    public var actionData: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        message: String,
        category: NotificationCategory = .general,
        iconName: String = "bell.fill",
        colorHex: String = "#5856D6",
        sourceApp: String = "NotchX",
        timestamp: Date = Date(),
        isRead: Bool = false,
        actionData: String? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.category = category
        self.iconName = iconName
        self.colorHex = colorHex
        self.sourceApp = sourceApp
        self.timestamp = timestamp
        self.isRead = isRead
        self.actionData = actionData
    }
    
    /// Default starter notifications
    public static var defaults: [NotificationItem] {
        [
            NotificationItem(
                title: "Welcome to NotchX",
                message: "Apple \"hello.\" dynamic greeting and floating dock ready.",
                category: .system,
                iconName: "sparkles",
                colorHex: "#AF52DE",
                sourceApp: "NotchX",
                timestamp: Date(),
                isRead: false
            ),
            NotificationItem(
                title: "Battery Status",
                message: "Power adapter connected. Optimal charging active.",
                category: .system,
                iconName: "bolt.fill",
                colorHex: "#34C759",
                sourceApp: "Power",
                timestamp: Date().addingTimeInterval(-180),
                isRead: true
            ),
            NotificationItem(
                title: "Calendar Sync",
                message: "Today's agenda synced with macOS Calendar.",
                category: .calendar,
                iconName: "calendar",
                colorHex: "#FF9500",
                sourceApp: "Calendar",
                timestamp: Date().addingTimeInterval(-600),
                isRead: true
            ),
            NotificationItem(
                title: "Audio Interceptor",
                message: "Volume and brightness OSD override active.",
                category: .media,
                iconName: "speaker.wave.3.fill",
                colorHex: "#007AFF",
                sourceApp: "Media",
                timestamp: Date().addingTimeInterval(-1200),
                isRead: true
            )
        ]
    }
}
