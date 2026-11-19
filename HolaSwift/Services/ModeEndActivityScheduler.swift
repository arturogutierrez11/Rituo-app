import DeviceActivity
import Foundation

@MainActor
final class ModeEndActivityScheduler {
    static let activityNamePrefix = "rituo.modeEnd."

    private static let scheduledNameKey = "rituo.modeEndActivityName"
    private static let scheduledEndDateKey = "rituo.modeEndDate"

    private let monitor = DeviceActivityMonitorExecutor()
    private let workQueue = DeviceActivityOperationQueue()
    private let calendar = Calendar.current
    private let metadataStore = SharedRitualActivityMetadataStore()
    private let debugStore = DeviceActivityDebugStore()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var scheduledEndDate: Date? {
        defaults.object(forKey: Self.scheduledEndDateKey) as? Date
    }

    func scheduleModeEnd(
        for mode: FocusMode,
        accountID: String?,
        at endDate: Date
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            workQueue.submit { [self] in
                do {
                    try await performScheduleModeEnd(
                        for: mode,
                        accountID: accountID,
                        at: endDate
                    )
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performScheduleModeEnd(
        for mode: FocusMode,
        accountID: String?,
        at endDate: Date
    ) async throws {
        await performCancel()

        let now = Date()
        guard endDate.timeIntervalSince(now) >= 15 * 60 else {
            throw ModeEndSchedulingError.durationTooShort
        }

        let activityName = DeviceActivityName(
            Self.activityNamePrefix + UUID().uuidString
        )
        try metadataStore.save(
            metadata: SharedRitualActivityMetadata(
                activityName: activityName.rawValue,
                userID: accountID,
                schedulerId: mode.id,
                coreRitualId: mode.coreModeId,
                title: mode.title,
                plannedEndAt: endDate,
                endHour: nil,
                endMinute: nil,
                blockAppInstallation: mode.blockAppInstallation,
                blockAdultContent: mode.blockAdultContent
            ),
            for: activityName.rawValue
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: now
            ),
            intervalEnd: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: endDate
            ),
            repeats: false
        )

        do {
            let monitorSpan = AppDiagnostics.shared.begin("device_activity.ModeEndActivityScheduler.start")
            defer { AppDiagnostics.shared.end("device_activity.ModeEndActivityScheduler.start", monitorSpan) }
            try await monitor.start(activityName.rawValue, schedule: schedule)
            defaults.set(activityName.rawValue, forKey: Self.scheduledNameKey)
            defaults.set(endDate, forKey: Self.scheduledEndDateKey)
            debugStore.log(
                "Fin automático de modo programado \(activityName.rawValue) para \(endDate)."
            )
        } catch {
            metadataStore.removeMetadata(for: activityName.rawValue)
            throw error
        }
    }

    func cancelCurrent() {
        workQueue.submit { [self] in await performCancel() }
    }

    private func performCancel() async {
        if let storedName = defaults.string(forKey: Self.scheduledNameKey) {
            let activityName = DeviceActivityName(storedName)
            let monitorSpan = AppDiagnostics.shared.begin("device_activity.ModeEndActivityScheduler.stop")
            defer { AppDiagnostics.shared.end("device_activity.ModeEndActivityScheduler.stop", monitorSpan) }
            metadataStore.removeMetadata(for: storedName)
            await monitor.stop([activityName.rawValue])
            debugStore.log("Fin automático de modo cancelado \(storedName).")
        }

        defaults.removeObject(forKey: Self.scheduledNameKey)
        defaults.removeObject(forKey: Self.scheduledEndDateKey)
    }
}

private enum ModeEndSchedulingError: LocalizedError {
    case durationTooShort

    var errorDescription: String? {
        "El límite del modo debe ser de al menos 15 minutos."
    }
}
