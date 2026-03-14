import Combine
import Foundation
import IOKit.ps

/// This class monitors the battery status.
class BatteryManager: ObservableObject {
    @Published var batteryLevel: Int = 0
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    private var timer: Timer?

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        // Battery status changes infrequently; update every 30 seconds.
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) {
            [weak self] _ in
            self?.updateBatteryStatus()
        }
        updateBatteryStatus()
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// This method updates the battery level and charging state.
    func updateBatteryStatus() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(snapshot)?
                .takeRetainedValue() as? [CFTypeRef]
        else {
            return
        }

        for source in sources {
            if let description = IOPSGetPowerSourceDescription(
                snapshot, source)?.takeUnretainedValue() as? [String: Any],
                let currentCapacity = description[
                    kIOPSCurrentCapacityKey as String] as? Int,
                let maxCapacity = description[kIOPSMaxCapacityKey as String]
                    as? Int,
                let charging = description[kIOPSIsChargingKey as String]
                    as? Bool,
                let powerSourceState = description[
                    kIOPSPowerSourceStateKey as String] as? String
            {
                let isAC = (powerSourceState == kIOPSACPowerValue)
                let newLevel = (currentCapacity * 100) / maxCapacity

                DispatchQueue.main.async {
                    if self.batteryLevel != newLevel {
                        self.batteryLevel = newLevel
                    }
                    if self.isCharging != charging {
                        self.isCharging = charging
                    }
                    if self.isPluggedIn != isAC {
                        self.isPluggedIn = isAC
                    }
                }
            }
        }
    }
}
