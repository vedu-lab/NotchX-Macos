// Copyright © 2026 Vedant. All rights reserved.
import Foundation
import SwiftUI
import AppKit

/// Singleton manager for NotchX notifications and the floating notification banner
@MainActor
public class NotificationPanelManager: ObservableObject {
    public static let shared = NotificationPanelManager()
    
    @Published public var notifications: [NotificationItem] = []
    @Published public var activeBanner: NotificationItem? = nil
    @Published public var isBannerVisible: Bool = false
    @Published public var isDockPanelVisible: Bool = false
    @Published public var unreadCount: Int = 0
    @Published public var selectedFilter: String = "All"
    
    public let filterCategories: [String] = ["All", "System", "Music", "Messages", "Others"]
    
    public var filteredNotifications: [NotificationItem] {
        switch selectedFilter {
        case "System":
            return notifications.filter { $0.category == .system }
        case "Music":
            return notifications.filter { $0.category == .media }
        case "Messages":
            return notifications.filter { $0.category == .messages }
        case "Others":
            return notifications.filter { $0.category == .general || $0.category == .calendar }
        default:
            return notifications
        }
    }
    
    public func count(for filter: String) -> Int {
        switch filter {
        case "System":
            return notifications.filter { $0.category == .system }.count
        case "Music":
            return notifications.filter { $0.category == .media }.count
        case "Messages":
            return notifications.filter { $0.category == .messages }.count
        case "Others":
            return notifications.filter { $0.category == .general || $0.category == .calendar }.count
        default:
            return notifications.count
        }
    }
    
    private var bannerDismissWorkItem: DispatchWorkItem?
    private let maxNotifications: Int = 30
    
    public func toggleDockPanel() {
        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isDockPanelVisible.toggle()
        }
        NotchWindowController.shared.updateFloatingBannerState()
    }
    
    private init() {
        loadNotifications()
        updateUnreadCount()
    }
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    private func loadNotifications() {
        if let data = UserDefaults.standard.data(forKey: "notchx.notifications"),
           let saved = try? JSONDecoder().decode([NotificationItem].self, from: data),
           !saved.isEmpty {
            self.notifications = saved
        } else {
            self.notifications = NotificationItem.defaults
        }
    }
    
    private func persistNotifications() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: "notchx.notifications")
        }
    }
    
    /// Posts a new notification and pops down the floating notification banner
    public func post(
        title: String,
        message: String,
        category: NotificationCategory = .general,
        iconName: String = "bell.fill",
        colorHex: String = "#5856D6",
        sourceApp: String = "NotchX",
        actionData: String? = nil,
        showBanner: Bool = true
    ) {
        guard SettingsManager.shared.notificationsEnabled else { return }
        
        let item = NotificationItem(
            id: UUID(),
            title: title,
            message: message,
            category: category,
            iconName: iconName,
            colorHex: colorHex,
            sourceApp: sourceApp,
            timestamp: Date(),
            isRead: false,
            actionData: actionData
        )
        
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            notifications.insert(item, at: 0)
            if notifications.count > maxNotifications {
                notifications = Array(notifications.prefix(maxNotifications))
            }
            updateUnreadCount()
        }
        persistNotifications()
        
        // Haptic feedback & chime
        AuralHapticsManager.shared.play(.sparkleTick, haptic: .levelChange)
        
        if showBanner {
            displayFloatingBanner(for: item)
        }
    }
    
    /// Displays the floating banner pill underneath the notch
    public func displayFloatingBanner(for item: NotificationItem) {
        bannerDismissWorkItem?.cancel()
        
        activeBanner = item
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            isBannerVisible = true
        }
        
        NotchWindowController.shared.updateFloatingBannerState()
        
        // Auto-dismiss after 5 seconds
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.dismissBanner()
        }
        bannerDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }
    
    /// Dismisses the floating banner pill
    public func dismissBanner() {
        bannerDismissWorkItem?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            isBannerVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, !self.isBannerVisible else { return }
            self.activeBanner = nil
        }
        
        NotchWindowController.shared.updateFloatingBannerState()
    }
    
    /// Marks an individual notification as read
    public func markAsRead(id: UUID) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
            updateUnreadCount()
            persistNotifications()
        }
    }
    
    /// Dismisses / deletes a notification
    public func dismissNotification(id: UUID) {
        if activeBanner?.id == id {
            dismissBanner()
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            notifications.removeAll(where: { $0.id == id })
            updateUnreadCount()
        }
        persistNotifications()
    }
    
    /// Clears all notifications
    public func clearAll() {
        dismissBanner()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            notifications.removeAll()
            updateUnreadCount()
        }
        persistNotifications()
        AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
    }
    
    /// Marks all notifications as read
    public func markAllAsRead() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            for index in notifications.indices {
                notifications[index].isRead = true
            }
            updateUnreadCount()
        }
        persistNotifications()
        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
    }
    
    /// Generates a test alert to demonstrate the floating notification panel
    public func triggerTestNotification() {
        let sampleAlerts: [(title: String, msg: String, cat: NotificationCategory, icon: String, hex: String, app: String)] = [
            ("AirDrop Received", "Screenshot 2026-09-30 at 18.25.png received from iPhone", .messages, "arrow.down.circle.fill", "#007AFF", "AirDrop"),
            ("Calendar Reminder", "Sprint Sync & Design Review starts in 10 minutes", .calendar, "calendar.badge.clock", "#FF9500", "Calendar"),
            ("Battery 100%", "MacBook battery is fully charged. Power source: Adapter", .system, "battery.100.bolt", "#34C759", "Power"),
            ("Apple Music", "Playing \"Starboy\" by The Weeknd • Liquid Audio Active", .media, "music.note", "#FF2D55", "Music"),
            ("NotchX Pro", "Liquid Glass aesthetic enabled with 0% CPU consumption", .general, "sparkles", "#AF52DE", "NotchX")
        ]
        
        let randomAlert = sampleAlerts.randomElement() ?? sampleAlerts[0]
        post(
            title: randomAlert.title,
            message: randomAlert.msg,
            category: randomAlert.cat,
            iconName: randomAlert.icon,
            colorHex: randomAlert.hex,
            sourceApp: randomAlert.app,
            showBanner: true
        )
    }
}
