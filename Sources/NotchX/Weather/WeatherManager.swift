import Foundation
import Combine

/// Day forecast item
public struct DailyForecastItem: Identifiable, Codable, Equatable {
    public var id: String { date }
    public let date: String
    public let dayName: String
    public let weatherCode: Int
    public let maxTemp: Double
    public let minTemp: Double
    
    public var iconName: String {
        WeatherManager.iconForWMO(weatherCode)
    }
}

/// Real-time live weather payload
public struct WeatherReport: Codable, Equatable {
    public let cityName: String
    public let temperature: Double
    public let apparentTemperature: Double
    public let weatherCode: Int
    public let humidity: Int
    public let windSpeed: Double
    public let conditionName: String
    public let dailyForecast: [DailyForecastItem]
    public let lastUpdated: Date
    
    public var iconName: String {
        WeatherManager.iconForWMO(weatherCode)
    }
}

/// Central Weather Manager providing live hyper-local weather & multi-day forecast
/// Uses free Open-Meteo API (zero API key needed) and IP geolocation.
public class WeatherManager: ObservableObject {
    public static let shared = WeatherManager()
    
    @Published public var report: WeatherReport?
    @Published public var isLoading: Bool = false
    @Published public var isFahrenheit: Bool = false {
        didSet {
            UserDefaults.standard.set(isFahrenheit, forKey: "notchx.weatherFahrenheit")
        }
    }
    @Published public var manualCity: String = "" {
        didSet {
            UserDefaults.standard.set(manualCity, forKey: "notchx.manualCity")
        }
    }
    
    private let defaults = UserDefaults.standard
    private var refreshTimer: Timer?
    
    private init() {
        self.isFahrenheit = defaults.bool(forKey: "notchx.weatherFahrenheit")
        self.manualCity = defaults.string(forKey: "notchx.manualCity") ?? ""
        loadCachedReport()
        refreshWeather()
        
        // Refresh every 25 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1500, repeats: true) { [weak self] _ in
            self?.refreshWeather()
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    private func loadCachedReport() {
        if let data = defaults.data(forKey: "notchx.cachedWeather"),
           let cached = try? JSONDecoder().decode(WeatherReport.self, from: data) {
            self.report = cached
        }
    }
    
    private func saveCachedReport(_ report: WeatherReport) {
        if let data = try? JSONEncoder().encode(report) {
            defaults.set(data, forKey: "notchx.cachedWeather")
        }
    }
    
    public func toggleTemperatureUnit() {
        isFahrenheit.toggle()
    }
    
    public func formattedTemp(_ celsius: Double) -> String {
        if isFahrenheit {
            let f = (celsius * 9 / 5) + 32
            return "\(Int(round(f)))°"
        } else {
            return "\(Int(round(celsius)))°"
        }
    }
    
    public func refreshWeather() {
        isLoading = true
        
        // Step 1: Detect location via IP geolocation
        let geoURLString = "http://ip-api.com/json/?fields=status,city,country,lat,lon"
        guard let geoURL = URL(string: geoURLString) else {
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: geoURL) { [weak self] data, _, error in
            guard let self = self else { return }
            
            var latitude = 37.7749
            var longitude = -122.4194
            var resolvedCity = "San Francisco"
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lat = json["lat"] as? Double,
               let lon = json["lon"] as? Double {
                latitude = lat
                longitude = lon
                if let city = json["city"] as? String, !city.isEmpty {
                    resolvedCity = city
                }
            }
            
            if !self.manualCity.trimmingCharacters(in: .whitespaces).isEmpty {
                resolvedCity = self.manualCity.trimmingCharacters(in: .whitespaces)
            }
            
            self.fetchOpenMeteo(latitude: latitude, longitude: longitude, cityName: resolvedCity)
        }.resume()
    }
    
    private func fetchOpenMeteo(latitude: Double, longitude: Double, cityName: String) {
        let meteoURLStr = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto"
        
        guard let url = URL(string: meteoURLStr) else {
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            defer {
                DispatchQueue.main.async { self.isLoading = false }
            }
            
            guard let data = data, error == nil,
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            guard let current = root["current"] as? [String: Any],
                  let temp = current["temperature_2m"] as? Double,
                  let apparent = current["apparent_temperature"] as? Double,
                  let code = current["weather_code"] as? Int,
                  let humidity = current["relative_humidity_2m"] as? Int,
                  let wind = current["wind_speed_10m"] as? Double else {
                return
            }
            
            var dailyItems: [DailyForecastItem] = []
            if let daily = root["daily"] as? [String: Any],
               let times = daily["time"] as? [String],
               let codes = daily["weather_code"] as? [Int],
               let maxs = daily["temperature_2m_max"] as? [Double],
               let mins = daily["temperature_2m_min"] as? [Double] {
                
                let count = min(times.count, min(codes.count, min(maxs.count, mins.count)))
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                let dayDf = DateFormatter()
                dayDf.dateFormat = "EEE"
                
                for i in 0..<min(count, 5) {
                    let dateStr = times[i]
                    var dName = "Today"
                    if i > 0, let d = df.date(from: dateStr) {
                        dName = dayDf.string(from: d)
                    }
                    dailyItems.append(DailyForecastItem(
                        date: dateStr,
                        dayName: dName,
                        weatherCode: codes[i],
                        maxTemp: maxs[i],
                        minTemp: mins[i]
                    ))
                }
            }
            
            let report = WeatherReport(
                cityName: cityName,
                temperature: temp,
                apparentTemperature: apparent,
                weatherCode: code,
                humidity: humidity,
                windSpeed: wind,
                conditionName: Self.conditionNameForWMO(code),
                dailyForecast: dailyItems,
                lastUpdated: Date()
            )
            
            DispatchQueue.main.async {
                self.report = report
                self.saveCachedReport(report)
            }
        }.resume()
    }
    
    // MARK: - WMO Weather Code Translators
    
    public static func conditionNameForWMO(_ code: Int) -> String {
        switch code {
        case 0: return "Clear Sky"
        case 1, 2, 3: return "Partly Cloudy"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Light Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Partly Cloudy"
        }
    }
    
    public static func iconForWMO(_ code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }
}
