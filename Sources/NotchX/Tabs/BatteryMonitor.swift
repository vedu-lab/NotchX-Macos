import Foundation
import IOKit.ps

/// Real-time macOS battery level and charging status monitor
public class BatteryMonitor: ObservableObject {
    public static let shared = BatteryMonitor()
    
    @Published public var level: Int = 100
    @Published public var isCharging: Bool = false
    
    private var timer: Timer?
    
    private init() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    public func update() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                let current = info[kIOPSCurrentCapacityKey as String] as? Int ?? 100
                let max = info[kIOPSMaxCapacityKey as String] as? Int ?? 100
                let charging = (info[kIOPSIsChargingKey as String] as? Bool) ?? false
                let percent = max > 0 ? Int((Double(current) / Double(max)) * 100) : 100
                DispatchQueue.main.async {
                    self.level = percent
                    self.isCharging = charging
                }
                return
            }
        }
    }
    
    public var iconName: String {
        if isCharging {
            return "battery.100.bolt"
        }
        if level > 85 { return "battery.100" }
        if level > 60 { return "battery.75" }
        if level > 35 { return "battery.50" }
        if level > 10 { return "battery.25" }
        return "battery.0"
    }
}
