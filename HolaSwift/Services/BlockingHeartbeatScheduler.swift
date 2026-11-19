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
@MainActor
final class BlockingHeartbeatScheduler {
    static let activityNamePrefix = "rituo.heartbeat."
    static let interval: TimeInterval = 2 * 60 * 60

    private let monitor = DeviceActivityMonitorExecutor()
    private let workQueue = DeviceActivityOperationQueue()
    private let calendar = Calendar.current
    private let suppressionStore = SharedRitualSuppressionStore()
    private let debugStore = DeviceActivityDebugStore()

    func scheduleIfNeeded() {
        workQueue.submit { [self] in await performScheduleIfNeeded() }
    }

    private func performScheduleIfNeeded() async {
        guard suppressionStore.heartbeatActivityName() == nil else { return }
        do {
            try await schedule()
        } catch {
            debugStore.log("No se pudo programar el latido de bloqueo: \(error.localizedDescription)")
        }
    }

    func cancelCurrent() {
        workQueue.submit { [self] in await performCancel() }
    }

    private func performCancel() async {
        guard let storedName = suppressionStore.heartbeatActivityName() else { return }
        suppressionStore.setHeartbeatActivityName(nil)
        let monitorSpan = AppDiagnostics.shared.begin("device_activity.BlockingHeartbeatScheduler.stop")
        defer { AppDiagnostics.shared.end("device_activity.BlockingHeartbeatScheduler.stop", monitorSpan) }
        await monitor.stop([storedName])
        debugStore.log("Latido de bloqueo cancelado \(storedName).")
    }

    private func schedule() async throws {
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

        suppressionStore.setHeartbeatActivityName(activityName.rawValue)
        suppressionStore.setHeartbeatExpiration(end)
        do {
            let monitorSpan = AppDiagnostics.shared.begin("device_activity.BlockingHeartbeatScheduler.start")
            defer { AppDiagnostics.shared.end("device_activity.BlockingHeartbeatScheduler.start", monitorSpan) }
            try await monitor.start(activityName.rawValue, schedule: schedule)
        } catch {
            suppressionStore.setHeartbeatActivityName(nil)
            throw error
        }
        debugStore.log("Latido de bloqueo programado \(activityName.rawValue) hasta \(end).")
    }
}
