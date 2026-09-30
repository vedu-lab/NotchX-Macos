import Foundation
import Combine
import AppKit

public enum WidgetType: String, CaseIterable, Codable, Identifiable {
    case weather = "Weather Forecast"
    case systemStats = "System Stats"
    case scratchpad = "Scratchpad"
    case quickLinks = "Quick Web Links"
    case calendarAgenda = "Calendar Agenda"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .weather: return "sun.max.fill"
        case .systemStats: return "gauge.with.needle"
        case .scratchpad: return "note.text"
        case .quickLinks: return "globe"
        case .calendarAgenda: return "calendar"
        }
    }
}

/// Central manager for user-customizable dashboard widgets
public class WidgetManager: ObservableObject {
    public static let shared = WidgetManager()
    
    @Published public var enabledWidgets: [WidgetType] = [.weather, .systemStats, .scratchpad, .quickLinks] {
        didSet { saveConfig() }
    }
    @Published public var isEditing: Bool = false
    @Published public var scratchpadText: String = "" {
        didSet {
            UserDefaults.standard.set(scratchpadText, forKey: "notchx.scratchpadText")
        }
    }
    
    // System stats live metrics
    @Published public var cpuUsage: Double = 12.0
    @Published public var ramUsage: Double = 48.0
    @Published public var diskFreeGB: Double = 240.0
    
    private var statsTimer: Timer?
    private let defaults = UserDefaults.standard
    
    private init() {
        self.scratchpadText = defaults.string(forKey: "notchx.scratchpadText") ?? ""
        loadConfig()
        startStatsMonitor()
    }
    
    deinit {
        statsTimer?.invalidate()
    }
    
    private func loadConfig() {
        if let data = defaults.data(forKey: "notchx.enabledWidgets"),
           let list = try? JSONDecoder().decode([WidgetType].self, from: data) {
            self.enabledWidgets = list
        }
    }
    
    private func saveConfig() {
        if let data = try? JSONEncoder().encode(enabledWidgets) {
            defaults.set(data, forKey: "notchx.enabledWidgets")
        }
    }
    
    public func isWidgetEnabled(_ type: WidgetType) -> Bool {
        enabledWidgets.contains(type)
    }
    
    public func toggleWidget(_ type: WidgetType) {
        if let idx = enabledWidgets.firstIndex(of: type) {
            if enabledWidgets.count > 1 {
                enabledWidgets.remove(at: idx)
            }
        } else {
            enabledWidgets.append(type)
        }
        AuralHapticsManager.shared.play(.tock, haptic: .alignment)
    }
    
    private func startStatsMonitor() {
        updateStats()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    private func updateStats() {
        // Read CPU load roughly via host_statistics64
        var cpuLoad: Double = 12.0
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let total = Double(cpuInfo.cpu_ticks.0 + cpuInfo.cpu_ticks.1 + cpuInfo.cpu_ticks.2 + cpuInfo.cpu_ticks.3)
            let busy = Double(cpuInfo.cpu_ticks.0 + cpuInfo.cpu_ticks.1 + cpuInfo.cpu_ticks.2)
            if total > 0 {
                cpuLoad = (busy / total) * 100.0
            }
        }
        
        // Read memory
        var stats = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var ramPct: Double = 50.0
        let kerr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }
        if kerr == KERN_SUCCESS {
            let active = Double(stats.active_count + stats.wire_count)
            let total = active + Double(stats.inactive_count + stats.free_count)
            if total > 0 {
                ramPct = (active / total) * 100.0
            }
        }
        
        // Disk free space
        var freeGB: Double = 180.0
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let freeBytes = attrs[.systemFreeSize] as? Int64 {
            freeGB = Double(freeBytes) / 1_073_741_824.0
        }
        
        DispatchQueue.main.async {
            self.cpuUsage = min(99.0, max(2.0, cpuLoad))
            self.ramUsage = min(99.0, max(10.0, ramPct))
            self.diskFreeGB = freeGB
        }
    }
}
