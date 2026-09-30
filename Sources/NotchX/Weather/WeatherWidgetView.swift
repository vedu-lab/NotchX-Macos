import SwiftUI
import AppKit

/// High-end luxury weather widget card for NotchX widgets dashboard (Compact, sleek proportions)
public struct WeatherWidgetView: View {
    @ObservedObject private var weatherMgr = WeatherManager.shared
    @ObservedObject private var hover = ItemHoverState()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top Row: City Name, Unit Toggle & Refresh
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
                
                Text(weatherMgr.report?.cityName ?? "Detecting...")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                // Unit Switcher (°C / °F)
                Button(action: {
                    weatherMgr.toggleTemperatureUnit()
                    AuralHapticsManager.shared.play(.tock, haptic: .alignment)
                }) {
                    Text(weatherMgr.isFahrenheit ? "°F" : "°C")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Toggle °C / °F")
                
                // Refresh Button
                Button(action: {
                    weatherMgr.refreshWeather()
                    AuralHapticsManager.shared.play(.sparkleTick, haptic: .generic)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .rotationEffect(.degrees(weatherMgr.isLoading ? 360 : 0))
                        .animation(weatherMgr.isLoading ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: weatherMgr.isLoading)
                }
                .buttonStyle(.plain)
                .help("Refresh Weather")
            }
            
            if let rep = weatherMgr.report {
                // Middle Row: Temp + Main Condition Icon
                HStack(spacing: 8) {
                    Image(systemName: rep.iconName)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 22))
                        .frame(width: 26, height: 26)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(weatherMgr.formattedTemp(rep.temperature))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(rep.conditionName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        
                        Text("Feels like \(weatherMgr.formattedTemp(rep.apparentTemperature)) · Wind \(Int(rep.windSpeed)) km/h")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 0)
                }
                
                // Bottom Row: 5-Day Mini Forecast Strip
                if !rep.dailyForecast.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(rep.dailyForecast) { day in
                            VStack(spacing: 1.5) {
                                Text(day.dayName)
                                    .font(.system(size: 7.5, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Image(systemName: day.iconName)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.system(size: 9.5))
                                    .frame(height: 12)
                                
                                Text("\(Int(round(weatherMgr.isFahrenheit ? (day.maxTemp * 9/5 + 32) : day.maxTemp)))°")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2.5)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
                }
            } else {
                // Placeholder loading skeleton
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Fetching weather forecast...")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 46)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(hover.isHovered ? 0.11 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(hover.isHovered ? 0.20 : 0.12), lineWidth: 0.6)
                )
        )
        .onHover { hover.isHovered = $0 }
    }
}

/// Full Weather Tab View for NotchX
public struct FullWeatherTabView: View {
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            WeatherWidgetView()
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

