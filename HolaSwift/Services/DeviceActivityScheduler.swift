import CryptoKit
import DeviceActivity
import Foundation

final class DeviceActivityScheduler {
    private static let scheduledNamesKey = "rituo.deviceActivity.scheduledNames"
    private static let scheduleFingerprintKey = "rituo.deviceActivity.scheduleFingerprint"
    private static let minimumMonitorDurationMinutes = 15

    private let center = DeviceActivityCenter()
    private let calendar = Calendar.current
    private let selectionStore = SharedRitualSelectionStore()
    private let metadataStore = SharedRitualActivityMetadataStore()
    private let debugStore = DeviceActivityDebugStore()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func reschedule(_ schedulers: [RitualScheduler]) throws {
        let fingerprint = try scheduleFingerprint(for: schedulers)
        let storedFingerprint = defaults.string(forKey: Self.scheduleFingerprintKey)
        let storedNames = defaults.stringArray(forKey: Self.scheduledNamesKey) ?? []

        if storedFingerprint == fingerprint, !storedNames.isEmpty {
            debugStore.log("Programación DeviceActivity sin cambios; se conserva.")
            return
        }

        stopPreviouslyScheduledActivities()
        debugStore.log("Reprogramando \(schedulers.count) rituales locales.")

        var scheduledNames: [String] = []
        for scheduler in schedulers where scheduler.selectedItemCount > 0 {
            guard scheduler.durationMinutes >= Self.minimumMonitorDurationMinutes else {
                debugStore.log(
                    "Saltando DeviceActivity para \(scheduler.title): duración \(scheduler.durationMinutes)m menor a \(Self.minimumMonitorDurationMinutes)m. Fallback local activo si la app está abierta."
                )
                continue
            }

            let names = try schedule(scheduler)
            scheduledNames.append(contentsOf: names.map(\.rawValue))
        }

        defaults.set(scheduledNames, forKey: Self.scheduledNamesKey)
        defaults.set(fingerprint, forKey: Self.scheduleFingerprintKey)
    }

    @discardableResult
    func schedule(_ scheduler: RitualScheduler) throws -> [DeviceActivityName] {
        var scheduledNames: [DeviceActivityName] = []

        for weekday in scheduler.weekdays {
            let name = activityName(for: scheduler, weekday: weekday)
            try selectionStore.save(selection: scheduler.selection, for: name.rawValue)
            try metadataStore.save(
                metadata: SharedRitualActivityMetadata(
                    activityName: name.rawValue,
                    schedulerId: scheduler.id.uuidString,
                    coreRitualId: scheduler.coreRitualId,
                    title: scheduler.title,
                    plannedEndAt: scheduler.endDate()
                ),
                for: name.rawValue
            )
            debugStore.log(
                "Agendando \(scheduler.title) \(weekday) \(Self.format(hour: scheduler.startHour, minute: scheduler.startMinute))-\(Self.format(hour: scheduler.endHour, minute: scheduler.endMinute)) items=\(scheduler.selectedItemCount)."
            )

            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(
                    calendar: calendar,
                    hour: scheduler.startHour,
                    minute: scheduler.startMinute,
                    weekday: weekday
                ),
                intervalEnd: DateComponents(
                    calendar: calendar,
                    hour: scheduler.endHour,
                    minute: scheduler.endMinute,
                    weekday: weekday
                ),
                repeats: true,
                warningTime: DateComponents(minute: 2)
            )

            try center.startMonitoring(name, during: schedule)
            debugStore.log("startMonitoring OK \(name.rawValue).")
            scheduledNames.append(name)
        }

        return scheduledNames
    }

    func stopMonitoring(_ schedulers: [RitualScheduler]) {
        stopMonitoring(_scheduledNames(for: schedulers))
    }

    func stopMonitoringCurrentInterval(for scheduler: RitualScheduler, on date: Date = .now) {
        let names = _scheduledNames(for: [scheduler])
        stopMonitoring(names)

        let stoppedNames = names.map(\.rawValue)
        stoppedNames.forEach {
            selectionStore.removeSelection(for: $0)
            metadataStore.removeMetadata(for: $0)
        }

        let storedNames = defaults.stringArray(forKey: Self.scheduledNamesKey) ?? []
        let remainingNames = storedNames.filter { !stoppedNames.contains($0) }
        defaults.set(remainingNames, forKey: Self.scheduledNamesKey)
        defaults.removeObject(forKey: Self.scheduleFingerprintKey)
        debugStore.log("Monitores pausados manualmente \(stoppedNames.count) para \(scheduler.title).")
    }

    private func stopMonitoring(_ names: [DeviceActivityName]) {
        guard !names.isEmpty else { return }
        center.stopMonitoring(names)
    }

    private func stopPreviouslyScheduledActivities() {
        let storedNames = defaults.stringArray(forKey: Self.scheduledNamesKey) ?? []
        let names = storedNames.map { DeviceActivityName($0) }
        stopMonitoring(names)
        storedNames.forEach {
            selectionStore.removeSelection(for: $0)
            metadataStore.removeMetadata(for: $0)
        }
        if !storedNames.isEmpty {
            debugStore.log("Detenidos \(storedNames.count) monitores anteriores.")
        }
        defaults.removeObject(forKey: Self.scheduledNamesKey)
    }

    private func scheduleFingerprint(for schedulers: [RitualScheduler]) throws -> String {
        let components = try schedulers
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { scheduler -> String in
                let selectionData = try JSONEncoder().encode(scheduler.selection)
                let selectionHash = SHA256.hash(data: selectionData)
                    .map { String(format: "%02x", $0) }
                    .joined()

                return [
                    scheduler.id.uuidString,
                    scheduler.coreRitualId ?? "",
                    scheduler.title,
                    "\(scheduler.startHour):\(scheduler.startMinute)",
                    "\(scheduler.endHour):\(scheduler.endMinute)",
                    scheduler.weekdays.sorted().map(String.init).joined(separator: ","),
                    selectionHash
                ].joined(separator: "|")
            }

        let data = Data(components.joined(separator: "||").utf8)
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func _scheduledNames(for schedulers: [RitualScheduler]) -> [DeviceActivityName] {
        schedulers.flatMap { scheduler in
            scheduler.weekdays.map { weekday in
                activityName(for: scheduler, weekday: weekday)
            }
        }
    }

    private func activityName(for scheduler: RitualScheduler, weekday: Int) -> DeviceActivityName {
        DeviceActivityName("rituo.ritual.\(scheduler.id.uuidString).weekday.\(weekday)")
    }

    private static func format(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}
