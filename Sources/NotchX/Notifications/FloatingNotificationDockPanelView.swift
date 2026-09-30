// Copyright © 2026 Vedant. All rights reserved.
import SwiftUI
import AppKit

/// Floating notification panel positioned directly under the floating dock bar
/// Features:
/// - Category filtering: All, System, Music, Messages, Others
/// - Liquid glass styling matching NotchBottomDockBarView
/// - Interactive notification cards with dismiss, clear all, and test alert simulation
/// - Unread badge indicators and direct haptic feedback
struct FloatingNotificationDockPanelView: View {
    @ObservedObject private var notificationManager = NotificationPanelManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        let isCompact = settings.notchExpandedHeight < 265
        let maxW = min(settings.notchExpandedWidth * 0.88, 540)
        let panelH: CGFloat = isCompact ? 165 : 185
        
        VStack(spacing: 5) {
            // === Top Header Toolbar ===
            NotificationPanelHeaderToolbar()
            
            // === Category Filter Bar (All, System, Music, Messages, Others) ===
            HStack(spacing: 4) {
                ForEach(notificationManager.filterCategories, id: \.self) { filter in
                    let isSelected = notificationManager.selectedFilter == filter
                    let filterCount = notificationManager.count(for: filter)
                    
                    CategoryFilterPill(
                        filter: filter,
                        iconName: filterIcon(for: filter),
                        isSelected: isSelected,
                        count: filterCount
                    ) {
                        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            notificationManager.selectedFilter = filter
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 1)
            
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 8)
            
            // === Notification Content Rows or Filter-Aware Empty State ===
            let list = notificationManager.filteredNotifications
            if list.isEmpty {
                NotificationPanelEmptyState(filter: notificationManager.selectedFilter)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(list) { item in
                            DockNotificationRow(item: item, isCompact: isCompact)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(width: maxW, height: panelH)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .opacity(0.50)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    Color.purple.opacity(0.32),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: Color.black.opacity(0.55), radius: 14, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -8)),
            removal: .scale(scale: 0.94, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -6))
        ))
    }
    
    private func filterIcon(for filter: String) -> String {
        switch filter {
        case "All": return "square.stack.fill"
        case "System": return "gearshape.fill"
        case "Music": return "music.note"
        case "Messages": return "message.fill"
        case "Others": return "ellipsis.circle.fill"
        default: return "bell.fill"
        }
    }
}

// MARK: - Header Toolbar Subview

private struct NotificationPanelHeaderToolbar: View {
    @ObservedObject private var notificationManager = NotificationPanelManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // Bell emblem + Title + Unread badge
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.purple)
                
                Text("Notifications")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
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
            
            Spacer()
            
            // Action Buttons: Test, Mark Read, Clear, Close
            HStack(spacing: 5) {
                Button(action: {
                    notificationManager.triggerTestNotification()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8.5))
                        Text("Test")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.90))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.30))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.purple.opacity(0.50), lineWidth: 0.6))
                }
                .buttonStyle(.plain)
                .help("Simulate floating alert")
                
                if !notificationManager.notifications.isEmpty {
                    if notificationManager.unreadCount > 0 {
                        Button(action: {
                            notificationManager.markAllAsRead()
                        }) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.70))
                                .padding(3.5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Mark all as read")
                    }
                    
                    Button(action: {
                        notificationManager.clearAll()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.70))
                            .padding(3.5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear all notifications")
                }
                
                // Close floating panel button
                Button(action: {
                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        notificationManager.isDockPanelVisible = false
                    }
                    NotchWindowController.shared.updateFloatingBannerState()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.60))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Hide notification panel")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }
}

// MARK: - Category Filter Pill Subview

private struct CategoryFilterPill: View {
    let filter: String
    let iconName: String
    let isSelected: Bool
    let count: Int
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 3.5) {
                Image(systemName: iconName)
                    .font(.system(size: 8, weight: isSelected ? .bold : .medium))
                
                Text(filter)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.55))
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 0.5)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.60))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isSelected ? Color.purple.opacity(0.40) : Color.white.opacity(0.05))
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.purple.opacity(0.60) : Color.white.opacity(0.08), lineWidth: 0.7)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State Subview

private struct NotificationPanelEmptyState: View {
    let filter: String
    
    private var emptyIcon: String {
        switch filter {
        case "System": return "gearshape"
        case "Music": return "music.note"
        case "Messages": return "bubble.left.and.bubble.right"
        default: return "bell.slash"
        }
    }
    
    private var emptyTitle: String {
        if filter == "All" {
            return "No Notifications"
        }
        return "No \(filter) Notifications"
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            Image(systemName: emptyIcon)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.35))
            Text(emptyTitle)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
            Text("New alerts float here under your floating dock.")
                .font(.system(size: 8.5))
                .foregroundColor(.white.opacity(0.40))
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Notification Row Subview

private struct DockNotificationRow: View {
    let item: NotificationItem
    let isCompact: Bool
    @ObservedObject private var notificationManager = NotificationPanelManager.shared
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Icon Emblem
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.category.color.opacity(0.85))
                Image(systemName: item.iconName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 20, height: 20)
            
            // Text Details
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("•")
                        .font(.system(size: 6))
                        .foregroundColor(.white.opacity(0.35))
                    
                    Text(item.sourceApp)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                    
                    Spacer()
                    
                    Text(relativeTimeString(from: item.timestamp))
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.40))
                    
                    if !item.isRead {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 4.5, height: 4.5)
                    }
                }
                
                Text(item.message)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(1)
            }
            
            // Dismiss button
            Button(action: {
                AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                notificationManager.dismissNotification(id: item.id)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.40))
                    .frame(width: 16, height: 16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(item.isRead ? Color.white.opacity(0.03) : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(item.isRead ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.5)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            AuralHapticsManager.shared.play(.tock, haptic: .alignment)
            notificationManager.markAsRead(id: item.id)
        }
    }
    
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
