import DeviceActivity
import Foundation

/// Keeps a lightweight, recurring DeviceActivity monitor alive while
/// blocking is active, purely so the DeviceActivityMonitor extension gets
/// woken up by the system every couple of hours even if the main app never
/// runs — e.g. after the phone runs out of battery and reboots. On each
/// wake-up the extension re-applies whatever shield should currently be
/// active from persisted state, then reschedules the next heartbeat itself
/// (see `RituoDeviceActivityMonitor.maintainHeartbeat`). This scheduler only
/// needs to kick off the first occurrence when blocking starts, and cancel
/// it when blocking ends normally.
final class BlockingHeartbeatScheduler {
    static let activityNamePrefix = "rituo.heartbeat."
    static let interval: TimeInterval = 2 * 60 * 60

    private let center = DeviceActivityCenter()
    private let calendar = Calendar.current
    private let suppressionStore = SharedRitualSuppressionStore()
    private let debugStore = DeviceActivityDebugStore()

    func scheduleIfNeeded() {
        guard suppressionStore.heartbeatActivityName() == nil else { return }
        do {
            try schedule()
        } catch {
            debugStore.log("No se pudo programar el latido de bloqueo: \(error.localizedDescription)")
        }
    }

    func cancelCurrent() {
        guard let storedName = suppressionStore.heartbeatActivityName() else { return }
        center.stopMonitoring([DeviceActivityName(storedName)])
        suppressionStore.setHeartbeatActivityName(nil)
        debugStore.log("Latido de bloqueo cancelado \(storedName).")
    }

    private func schedule() throws {
        let activityName = DeviceActivityName(Self.activityNamePrefix + UUID().uuidString)
        let now = Date()
        let end = now.addingTimeInterval(Self.interval)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: now
            ),
            intervalEnd: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: end
            ),
            repeats: false
        )

        try center.startMonitoring(activityName, during: schedule)
        suppressionStore.setHeartbeatActivityName(activityName.rawValue)
        debugStore.log("Latido de bloqueo programado \(activityName.rawValue) hasta \(end).")
    }
}
