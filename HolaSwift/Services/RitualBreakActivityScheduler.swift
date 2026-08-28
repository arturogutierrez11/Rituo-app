import DeviceActivity
import Foundation

final class RitualBreakActivityScheduler {
    static let activityNamePrefix = "rituo.ritualBreakEnd."

    private static let scheduledNameKey = "rituo.ritualBreakActivityName"
    private static let minimumMonitorDuration: TimeInterval = 15 * 60

    private let center = DeviceActivityCenter()
    private let calendar = Calendar.current
    private let selectionStore = SharedRitualSelectionStore()
    private let metadataStore = SharedRitualActivityMetadataStore()
    private let debugStore = DeviceActivityDebugStore()
    private let suppressionStore = SharedRitualSuppressionStore()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func scheduleBreakEnd(for scheduler: RitualScheduler, accountID: String?, until breakUntil: Date) throws {
        cancelCurrent()

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

        try center.startMonitoring(activityName, during: schedule)
        defaults.set(activityName.rawValue, forKey: Self.scheduledNameKey)
        suppressionStore.setRitualBreakActivityName(activityName.rawValue)
        debugStore.log("Recreo de ritual programado con DeviceActivity \(activityName.rawValue) desde \(now) hasta \(monitorEndDate), warning en \(warningLeadTime)s.")
    }

    func cancelCurrent() {
        guard let storedName =
            defaults.string(forKey: Self.scheduledNameKey)
            ?? suppressionStore.ritualBreakActivityName() else {
            return
        }

        let activityName = DeviceActivityName(storedName)
        center.stopMonitoring([activityName])
        selectionStore.removeSelection(for: storedName)
        metadataStore.removeMetadata(for: storedName)
        defaults.removeObject(forKey: Self.scheduledNameKey)
        suppressionStore.setRitualBreakActivityName(nil)
        debugStore.log("Recreo de ritual cancelado \(storedName).")
    }
}
