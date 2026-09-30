// Copyright © 2026 Vedant. All rights reserved.
import SwiftUI
import AppKit

/// Floating notification pill that hovers below the notch, matching the floating dock bar aesthetics
struct FloatingNotificationBannerView: View {
    @ObservedObject private var notificationManager = NotificationPanelManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject var viewModel: NotchViewModel
    
    var body: some View {
        if let banner = notificationManager.activeBanner, notificationManager.isBannerVisible {
            HStack(spacing: 10) {
                // App Icon / Category Emblem
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(banner.category.color.opacity(0.85))
                        .shadow(color: banner.category.color.opacity(0.4), radius: 3)
                    
                    Image(systemName: banner.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)
                
                // Content: Title & Message
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(banner.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("•")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text(banner.sourceApp)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Text(banner.message)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.80))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 6)
                
                // Quick Open Button
                Button(action: {
                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                    notificationManager.markAsRead(id: banner.id)
                    notificationManager.dismissBanner()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        notificationManager.isDockPanelVisible = true
                    }
                    viewModel.setHovered(true)
                    NotchWindowController.shared.updateFloatingBannerState()
                }) {
                    Text("View")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Close button
                Button(action: {
                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                    notificationManager.dismissBanner()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.60))
                        .frame(width: 18, height: 18)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 360)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.72))
                    .overlay(
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            .clipShape(Capsule())
                            .opacity(0.4)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(0.55), radius: 12, y: 5)
            )
            .contentShape(Capsule())
            .onTapGesture {
                AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                notificationManager.markAsRead(id: banner.id)
                notificationManager.dismissBanner()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    notificationManager.isDockPanelVisible = true
                }
                viewModel.setHovered(true)
                NotchWindowController.shared.updateFloatingBannerState()
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.88, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -10)),
                removal: .scale(scale: 0.90, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -8))
            ))
        }
    }
}
