// Copyright © 2026 Vedant. All rights reserved.
import SwiftUI
import AppKit

/// Category filter state for Notifications tab without using @State macro
public class NotificationsTabViewModel: ObservableObject {
    public static let shared = NotificationsTabViewModel()
    @Published public var selectedCategory: String = "All"
    public init() {}
}

/// Full Notification Center view embedded inside the NotchX expanded notch tab router
struct NotificationsTabView: View {
    @ObservedObject private var notificationManager = NotificationPanelManager.shared
    @ObservedObject private var tabVM = NotificationsTabViewModel.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    private let filterCategories = ["All", "System", "Messages", "Calendar", "Media"]
    
    private var filteredNotifications: [NotificationItem] {
        if tabVM.selectedCategory == "All" {
            return notificationManager.notifications
        }
        return notificationManager.notifications.filter { $0.category.rawValue == tabVM.selectedCategory }
    }
    
    var body: some View {
        let isCompact = settings.notchExpandedHeight < 265
        
        VStack(spacing: isCompact ? 6 : 8) {
            // === Top Filter & Action Bar ===
            HStack(spacing: 8) {
                // Header with bell badge
                HStack(spacing: 5) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: isCompact ? 10 : 12))
                        .foregroundColor(.purple)
                    
                    Text("Notifications")
                        .font(.system(size: isCompact ? 11 : 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if notificationManager.unreadCount > 0 {
                        Text("\(notificationManager.unreadCount)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                }
                
                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(filterCategories, id: \.self) { cat in
                            let isSelected = tabVM.selectedCategory == cat
                            Button(action: {
                                AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                                    tabVM.selectedCategory = cat
                                }
                            }) {
                                Text(cat)
                                    .font(.system(size: isCompact ? 9 : 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.60))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? Color.white.opacity(0.35) : Color.clear, lineWidth: 0.75)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer(minLength: 4)
                
                // Action Buttons: Test Notification, Mark All Read, Clear All
                HStack(spacing: 5) {
                    // Test Notification Button
                    Button(action: {
                        notificationManager.triggerTestNotification()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8.5))
                            Text("Test")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.28))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.purple.opacity(0.5), lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Simulate incoming floating notification")
                    
                    if !notificationManager.notifications.isEmpty {
                        // Mark All as Read
                        if notificationManager.unreadCount > 0 {
                            Button(action: {
                                notificationManager.markAllAsRead()
                            }) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.70))
                                    .padding(4)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Mark all as read")
                        }
                        
                        // Clear All
                        Button(action: {
                            notificationManager.clearAll()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.70))
                                .padding(4)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Clear all notifications")
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // === Notification List or Empty State ===
            if filteredNotifications.isEmpty {
                emptyStateView(isCompact: isCompact)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredNotifications) { item in
                            notificationCard(item: item, isCompact: isCompact)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
    }
    
    // MARK: - Notification Card
    
    private func notificationCard(item: NotificationItem, isCompact: Bool) -> some View {
        HStack(alignment: .top, spacing: 9) {
            // App Icon / Category Tint
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.category.color.opacity(0.85))
                    .shadow(color: item.category.color.opacity(0.4), radius: 3)
                
                Image(systemName: item.iconName)
                    .font(.system(size: isCompact ? 10 : 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: isCompact ? 24 : 28, height: isCompact ? 24 : 28)
            .padding(.top, 1)
            
            // Notification Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 5) {
                    Text(item.title)
                        .font(.system(size: isCompact ? 11 : 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("•")
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.35))
                    
                    Text(item.sourceApp)
                        .font(.system(size: isCompact ? 8.5 : 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                    
                    Spacer()
                    
                    // Relative Time
                    Text(relativeTimeString(from: item.timestamp))
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                    
                    // Unread Indicator Dot
                    if !item.isRead {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 5, height: 5)
                            .shadow(color: Color.purple.opacity(0.8), radius: 2)
                    }
                }
                
                Text(item.message)
                    .font(.system(size: isCompact ? 9.5 : 10.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.82))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Dismiss button
            Button(action: {
                AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                notificationManager.dismissNotification(id: item.id)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.40))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(item.isRead ? Color.white.opacity(0.04) : Color.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            item.isRead ? Color.white.opacity(0.08) : Color.white.opacity(0.18),
                            lineWidth: 0.75
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            AuralHapticsManager.shared.play(.tock, haptic: .alignment)
            notificationManager.markAsRead(id: item.id)
        }
    }
    
    // MARK: - Empty State View
    
    private func emptyStateView(isCompact: Bool) -> some View {
        VStack(spacing: 8) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "bell.slash")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white.opacity(0.50))
            }
            
            VStack(spacing: 2) {
                Text("No Notifications")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.90))
                
                Text("All caught up! New alerts will float below the notch.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.50))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                notificationManager.triggerTestNotification()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("Send Test Notification")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.purple.opacity(0.35))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.purple.opacity(0.6), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Relative Time Helper
    
    private func relativeTimeString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            return "\(seconds / 60)m ago"
        } else if seconds < 86400 {
            return "\(seconds / 3600)h ago"
        } else {
            return "\(seconds / 86400)d ago"
        }
    }
}
