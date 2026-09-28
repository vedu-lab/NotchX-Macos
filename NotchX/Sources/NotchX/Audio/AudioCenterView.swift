import SwiftUI
import AppKit
import CoreAudio

/// Clean helper state avoiding the broken @State macro in Swift toolchain
public class AudioCenterViewState: ObservableObject {
    public static let shared = AudioCenterViewState()
    @Published public var hoveredTrackID: String? = nil
    @Published public var hoveredDeviceID: AudioDeviceID? = nil
}

/// Dynamic Audio Center view embedded in NotchX:
/// 1. Output Device Routing: 1-click audio switching between MacBook Speakers, AirPods, External Displays
/// 2. Per-App Volume Sliders: Independent volume attenuation & mute for Spotify, Zoom, Music, Chrome, etc.
public struct AudioCenterView: View {
    @ObservedObject private var routingManager = AudioRoutingManager.shared
    @ObservedObject private var state = AudioCenterViewState.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Title & Output Devices Count
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                    Text("AUDIO ROUTING & PER-APP VOLUME")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .tracking(0.8)
                }
                
                Spacer()
                
                Text("\(routingManager.outputDevices.count) Devices Active")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 4)
            
            // Section 1: 1-Click Hardware Output Device Switcher
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(routingManager.outputDevices) { device in
                        outputDevicePill(device: device)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 0.5)
                .padding(.vertical, 2)
            
            // Section 2: Per-App Volume Controls
            if routingManager.activeAppTracks.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.35))
                        Text("No active media applications running")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.40))
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(routingManager.activeAppTracks) { track in
                        appVolumeRow(track: track)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    // MARK: - Output Device Pill
    
    private func outputDevicePill(device: AudioOutputDevice) -> some View {
        let isSelected = device.isDefault
        let isHovered = state.hoveredDeviceID == device.id
        
        return Button(action: {
            routingManager.selectOutputDevice(id: device.id)
            AuralHapticsManager.shared.play(.tock, haptic: .alignment)
        }) {
            HStack(spacing: 7) {
                Image(systemName: device.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                Text(device.name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                    .lineLimit(1)
                
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 5, height: 5)
                        .shadow(color: .blue, radius: 3)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.blue.opacity(0.40)
                            : (isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.10))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? Color.blue.opacity(0.7) : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            state.hoveredDeviceID = isHovering ? device.id : nil
        }
    }
    
    // MARK: - Per-App Volume Row
    
    private func appVolumeRow(track: AppAudioTrack) -> some View {
        HStack(spacing: 10) {
            // App Icon
            if let icon = track.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 22, height: 22)
            }
            
            // App Name
            Text(track.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 82, alignment: .leading)
                .lineLimit(1)
            
            // Interactive Slider Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 7)
                    
                    // Active Fill
                    Capsule()
                        .fill(
                            track.isMuted
                                ? LinearGradient(colors: [Color.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(0, min(geo.size.width * CGFloat(track.volume), geo.size.width)), height: 7)
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = Double(value.location.x / geo.size.width)
                            routingManager.setAppVolume(bundleID: track.bundleID, volume: fraction)
                        }
                )
            }
            .frame(height: 20)
            
            // Percentage Label
            Text(track.isMuted ? "0%" : "\(Int(track.volume * 100))%")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(track.isMuted ? .white.opacity(0.4) : .white.opacity(0.85))
                .frame(width: 34, alignment: .trailing)
            
            // Mute / Unmute Button
            Button(action: {
                routingManager.toggleAppMute(bundleID: track.bundleID)
                AuralHapticsManager.shared.play(.mechanicalClick, haptic: .generic)
            }) {
                Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(track.isMuted ? .red : .white.opacity(0.75))
                    .frame(width: 24, height: 24)
                    .background(track.isMuted ? Color.red.opacity(0.2) : Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
