import DeviceActivity
import Foundation

@MainActor
final class RitualBreakActivityScheduler {
    static let activityNamePrefix = "rituo.ritualBreakEnd."

    private static let scheduledNameKey = "rituo.ritualBreakActivityName"
    private static let minimumMonitorDuration: TimeInterval = 15 * 60

    private let monitor = DeviceActivityMonitorExecutor()
    private let workQueue = DeviceActivityOperationQueue()
    private let calendar = Calendar.current
    private let selectionStore = SharedRitualSelectionStore()
    private let metadataStore = SharedRitualActivityMetadataStore()
    private let debugStore = DeviceActivityDebugStore()
    private let suppressionStore = SharedRitualSuppressionStore()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func scheduleBreakEnd(for scheduler: RitualScheduler, accountID: String?, until breakUntil: Date,
                          completion: @escaping @MainActor @Sendable (Error?) -> Void) {
        workQueue.submit { [self] in
            do {
                try await performScheduleBreakEnd(for: scheduler, accountID: accountID, until: breakUntil)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    private func performScheduleBreakEnd(for scheduler: RitualScheduler, accountID: String?, until breakUntil: Date) async throws {
        await performCancel()

        let activityName = DeviceActivityName(Self.activityNamePrefix + UUID().uuidString)
        try selectionStore.save(selection: scheduler.selection, for: activityName.rawValue)
        try metadataStore.save(
            metadata: SharedRitualActivityMetadata(
                activityName: activityName.rawValue,
                userID: accountID,
                schedulerId: scheduler.id.uuidString,
                coreRitualId: scheduler.coreRitualId,
                title: scheduler.title,
                plannedEndAt: nil,
                endHour: nil,
                endMinute: nil,
                blockAppInstallation: scheduler.blockAppInstallation,
                blockAdultContent: scheduler.blockAdultContent
            ),
            for: activityName.rawValue
        )

        let now = Date()
        let requestedBreakDuration = max(60, breakUntil.timeIntervalSince(now))
        let monitorDuration = max(Self.minimumMonitorDuration, requestedBreakDuration)
        let monitorEndDate = now.addingTimeInterval(monitorDuration)
        let warningLeadTime = max(1, Int(ceil(monitorDuration - requestedBreakDuration)))
        let intervalStart = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now
        )
        let intervalEnd = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: monitorEndDate
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            repeats: false,
            warningTime: DateComponents(
                minute: warningLeadTime / 60,
                second: warningLeadTime % 60
            )
        )

        let monitorSpan = AppDiagnostics.shared.begin("device_activity.RitualBreakActivityScheduler.start")
        defer { AppDiagnostics.shared.end("device_activity.RitualBreakActivityScheduler.start", monitorSpan) }
        defaults.set(activityName.rawValue, forKey: Self.scheduledNameKey)
        suppressionStore.setRitualBreakActivityName(activityName.rawValue)
        do {
            try await monitor.start(activityName.rawValue, schedule: schedule)
        } catch {
            await performCancel()
            throw error
        }
        debugStore.log("Recreo de ritual programado con DeviceActivity \(activityName.rawValue) desde \(now) hasta \(monitorEndDate), warning en \(warningLeadTime)s.")
    }

    func cancelCurrent() {
        workQueue.submit { [self] in await performCancel() }
    }

    private func performCancel() async {
        guard let storedName =
            defaults.string(forKey: Self.scheduledNameKey)
            ?? suppressionStore.ritualBreakActivityName() else {
            return
        }

        let activityName = DeviceActivityName(storedName)
        let monitorSpan = AppDiagnostics.shared.begin("device_activity.RitualBreakActivityScheduler.stop")
        defer { AppDiagnostics.shared.end("device_activity.RitualBreakActivityScheduler.stop", monitorSpan) }
        // Invalidate the callback before asking Screen Time to stop it.
        selectionStore.removeSelection(for: storedName)
        metadataStore.removeMetadata(for: storedName)
        defaults.removeObject(forKey: Self.scheduledNameKey)
        suppressionStore.setRitualBreakActivityName(nil)
        await monitor.stop([activityName.rawValue])
        debugStore.log("Recreo de ritual cancelado \(storedName).")
    }
}
