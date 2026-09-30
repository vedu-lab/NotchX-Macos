import SwiftUI
import AppKit

/// Dynamic Island-inspired Widgets Hub (NotchPop / LaunchMe style)
public struct WidgetsTabView: View {
    @ObservedObject private var widgetMgr = WidgetManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 6) {
            // Header: Section label + Edit / Customize Button
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.blue)
                    Text("DASHBOARD")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .tracking(0.6)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        widgetMgr.isEditing.toggle()
                    }
                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: widgetMgr.isEditing ? "checkmark.circle.fill" : "slider.horizontal.2.square")
                            .font(.system(size: 9, weight: .bold))
                        Text(widgetMgr.isEditing ? "Done" : "Customize")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(widgetMgr.isEditing ? .green : .white.opacity(0.75))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(widgetMgr.isEditing ? 0.18 : 0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            
            // Edit Mode: Widget Toggles Strip
            if widgetMgr.isEditing {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(WidgetType.allCases) { type in
                            let enabled = widgetMgr.isWidgetEnabled(type)
                            Button(action: { widgetMgr.toggleWidget(type) }) {
                                HStack(spacing: 3) {
                                    Image(systemName: enabled ? "checkmark" : "plus")
                                        .font(.system(size: 8, weight: .bold))
                                    Text(type.rawValue)
                                        .font(.system(size: 8.5, weight: .medium))
                                }
                                .foregroundColor(enabled ? .white : .white.opacity(0.5))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(enabled ? Color.blue.opacity(0.7) : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 1)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Fluid Adaptive Grid of Widgets
            GeometryReader { geo in
                let isWide = geo.size.width >= 480
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        // Weather is shown exclusively in the dedicated Weather tab
                        
                        // Dual Column or Stacked Row for Secondary Widgets
                        if isWide {
                            HStack(alignment: .top, spacing: 6) {
                                if widgetMgr.isWidgetEnabled(.systemStats) {
                                    systemStatsCard
                                }
                                if widgetMgr.isWidgetEnabled(.scratchpad) {
                                    scratchpadCard
                                }
                            }
                        } else {
                            if widgetMgr.isWidgetEnabled(.systemStats) {
                                systemStatsCard
                            }
                            if widgetMgr.isWidgetEnabled(.scratchpad) {
                                scratchpadCard
                            }
                        }
                        
                        // Quick Web Links
                        if widgetMgr.isWidgetEnabled(.quickLinks) {
                            quickLinksCard
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - System Stats Card
    
    private var systemStatsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.green)
                Text("SYSTEM METRICS")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            
            HStack(spacing: 5) {
                metricPill(label: "CPU", val: "\(Int(widgetMgr.cpuUsage))%", icon: "speedometer", tint: .green)
                metricPill(label: "RAM", val: "\(Int(widgetMgr.ramUsage))%", icon: "memorychip", tint: .purple)
                metricPill(label: "DISK", val: "\(Int(widgetMgr.diskFreeGB))GB", icon: "internaldrive", tint: .blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }
    
    private func metricPill(label: String, val: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 2.5) {
                Image(systemName: icon)
                    .font(.system(size: 7.5))
                    .foregroundColor(tint)
                Text(label)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
            }
            Text(val)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
    
    // MARK: - Scratchpad Card
    
    private var scratchpadCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.yellow)
                Text("QUICK SCRATCHPAD")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                if !widgetMgr.scratchpadText.isEmpty {
                    Button(action: { widgetMgr.scratchpadText = "" }) {
                        Image(systemName: "trash")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            TextField("Jot down quick thoughts here...", text: $widgetMgr.scratchpadText)
                .textFieldStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }
    
    // MARK: - Quick Links Card
    
    private var quickLinksCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.cyan)
                Text("QUICK BOOKMARKS")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    linkCapsule(title: "Google", url: "https://google.com", icon: "magnifyingglass", color: .blue)
                    linkCapsule(title: "GitHub", url: "https://github.com", icon: "chevron.left.forwardslash.chevron.right", color: .purple)
                    linkCapsule(title: "ChatGPT", url: "https://chatgpt.com", icon: "bubble.left.and.bubble.right.fill", color: .green)
                    linkCapsule(title: "YouTube", url: "https://youtube.com", icon: "play.rectangle.fill", color: .red)
                    linkCapsule(title: "Twitter/X", url: "https://x.com", icon: "bubble.right.fill", color: .white)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
                )
        )
    }
    
    private func linkCapsule(title: String, url: String, icon: String, color: Color) -> some View {
        Button(action: {
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
                AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
            }
        }) {
            HStack(spacing: 3.5) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
