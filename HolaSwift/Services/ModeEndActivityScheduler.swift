import DeviceActivity
import Foundation

final class ModeEndActivityScheduler: @unchecked Sendable {
    static let activityNamePrefix = "rituo.modeEnd."

    private static let scheduledNameKey = "rituo.modeEndActivityName"
    private static let scheduledEndDateKey = "rituo.modeEndDate"

    private let center = DeviceActivityCenter()
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
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    try scheduleModeEndSynchronously(
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

    private func scheduleModeEndSynchronously(
        for mode: FocusMode,
        accountID: String?,
        at endDate: Date
    ) throws {
        cancelCurrent()

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
            try center.startMonitoring(activityName, during: schedule)
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
        if let storedName = defaults.string(forKey: Self.scheduledNameKey) {
            let activityName = DeviceActivityName(storedName)
            center.stopMonitoring([activityName])
            metadataStore.removeMetadata(for: storedName)
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
