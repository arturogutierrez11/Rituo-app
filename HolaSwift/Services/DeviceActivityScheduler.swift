import CryptoKit
import DeviceActivity
import FamilyControls
import Foundation

final class DeviceActivityScheduler {
    private static let scheduledNamesKey = "rituo.deviceActivity.scheduledNames"
    private static let scheduleFingerprintKey = "rituo.deviceActivity.scheduleFingerprint"
    private static let minimumMonitorDurationMinutes = 15
    private static let maximumActivities = 20
    private static let reservedActivities = 3
    private static let ritualPrefix = "rituo.ritual."

    private enum SchedulingFailure: LocalizedError {
        case capacity, stagingCapacity, systemChanged, sharedStateUnavailable, recoveryIncomplete
        var errorDescription: String? {
            switch self {
            case .capacity:
                return "Hay demasiados rituales o días para programarlos automáticamente. Reducí la configuración. Se conservaron los horarios anteriores."
            case .stagingCapacity:
                return "No hay espacio para cambiar todos los horarios de forma segura. Se conservó la programación anterior. Reducí la cantidad de rituales e intentá nuevamente."
            case .systemChanged:
                return "iOS cambió la programación durante la operación. Volvé a abrir Rituo para intentarlo nuevamente."
            case .sharedStateUnavailable:
                return "No se pudo guardar la configuración para el bloqueo automático. Se intentó recuperar la programación anterior."
            case .recoveryIncomplete:
                return "No se pudo recuperar toda la programación automática. Revisá tus rituales y compartí un diagnóstico con soporte."
            }
        }
    }

    private struct PlannedActivity {
        let name: String
        let selection: FamilyActivitySelection
        let metadata: SharedRitualActivityMetadata
        let registration: RitualMonitorRegistration
    }

    private struct PreviousActivity {
        let name: String
        let selection: FamilyActivitySelection?
        let metadata: SharedRitualActivityMetadata?
        let registration: RitualMonitorRegistration?
    }

    private let monitor = DeviceActivityMonitorExecutor()
    private var pendingWork: Task<Void, Never>?
    private let calendar = Calendar.current
    private let selectionStore = SharedRitualSelectionStore()
    private let metadataStore = SharedRitualActivityMetadataStore()
    private let activityStateStore = SharedRitualActivityStateStore()
    private let debugStore = DeviceActivityDebugStore()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // All commands preserve submission order, including logout and manual stops.
    func reschedule(_ schedulers: [RitualScheduler], userID: String?, completion: @escaping @MainActor (Error?) -> Void) {
        enqueue {
            do {
                try await self.performReschedule(schedulers, userID: userID)
                completion(nil)
            } catch {
                self.debugStore.log("Error al programar rituales: \(error.localizedDescription)")
                completion(error)
            }
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = pendingWork
        pendingWork = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    private func performReschedule(_ schedulers: [RitualScheduler], userID: String?) async throws {
        let diagnosticSpan = AppDiagnostics.shared.begin("device_activity.reschedule")
        defer { AppDiagnostics.shared.end("device_activity.reschedule", diagnosticSpan) }

        // Encode the whole plan before writing shared state or changing iOS monitors.
        let plan = try makePlan(schedulers, userID: userID)
        let desiredNames = Set(plan.map(\.name))
        let nativeNames = await monitor.names()
        let nativeRituals = Set(nativeNames.filter { $0.hasPrefix(Self.ritualPrefix) })
        let otherCount = nativeNames.subtracting(nativeRituals).count
        let fingerprint = try scheduleFingerprint(for: schedulers, userID: userID)
        let oldFingerprint = defaults.string(forKey: Self.scheduleFingerprintKey)
        let storedNames = defaults.stringArray(forKey: Self.scheduledNamesKey) ?? []

        guard desiredNames.count + max(Self.reservedActivities, otherCount) <= Self.maximumActivities else {
            debugStore.log("Capacidad insuficiente rituales=\(desiredNames.count) auxiliares=\(otherCount). Programación anterior conservada.")
            throw SchedulingFailure.capacity
        }
        // Staging must fit too: never destroy old schedules just to make room.
        guard nativeNames.union(desiredNames).count <= Self.maximumActivities else {
            throw SchedulingFailure.stagingCapacity
        }
        if oldFingerprint == fingerprint, nativeRituals == desiredNames,
           Set(storedNames) == desiredNames,
           plan.allSatisfy({ selectionStore.loadSelection(for: $0.name) != nil && metadataStore.loadMetadata(for: $0.name) != nil }) {
            debugStore.log("Programación DeviceActivity sin cambios; se conservan \(desiredNames.count) monitores.")
            return
        }

        var previous: [String: PreviousActivity] = [:]
        for entry in plan {
            let registration = await monitor.registration(entry.name)
            guard !nativeNames.contains(entry.name) || registration != nil else { throw SchedulingFailure.systemChanged }
            previous[entry.name] = PreviousActivity(name: entry.name,
                selection: selectionStore.loadSelection(for: entry.name),
                metadata: metadataStore.loadMetadata(for: entry.name), registration: registration)
        }
        // A process interruption must not leave an apparently confirmed fingerprint.
        defaults.removeObject(forKey: Self.scheduleFingerprintKey)
        let tracked = Set(storedNames).union(nativeRituals).union(desiredNames)
        defaults.set(tracked.sorted(), forKey: Self.scheduledNamesKey)
        var prepared: [String] = []
        var touchedMonitors = Set<String>()
        do {
            for entry in plan {
                prepared.append(entry.name)
                try selectionStore.save(selection: entry.selection, for: entry.name)
                try metadataStore.save(metadata: entry.metadata, for: entry.name)
                guard selectionStore.loadSelection(for: entry.name) != nil,
                      metadataStore.loadMetadata(for: entry.name) != nil else {
                    throw SchedulingFailure.sharedStateUnavailable
                }
                let old = previous[entry.name]!
                if old.registration != entry.registration || old.selection == nil || old.metadata == nil {
                    touchedMonitors.insert(entry.name)
                    try await monitor.register(entry.name, registration: entry.registration)
                    debugStore.log("startMonitoring OK \(entry.name).")
                }
            }
            guard desiredNames.isSubset(of: await monitor.names()) else { throw SchedulingFailure.systemChanged }
        } catch {
            let originalError = error
            var recovered = true
            for name in prepared.reversed() {
                guard let old = previous[name] else { continue }
                do {
                    if let selection = old.selection { try selectionStore.save(selection: selection, for: name) }
                    else { selectionStore.removeSelection(for: name) }
                    if let metadata = old.metadata { try metadataStore.save(metadata: metadata, for: name) }
                    else { metadataStore.removeMetadata(for: name) }
                } catch { recovered = false }
                if touchedMonitors.contains(name) {
                    if let registration = old.registration {
                        do { try await monitor.register(name, registration: registration) }
                        catch { recovered = false }
                    } else {
                        await monitor.stop([name])
                        activityStateStore.remove(activityName: name)
                    }
                }
            }
            let remaining = await monitor.names()
            recovered = recovered && nativeRituals.isSubset(of: remaining)
            if recovered {
                defaults.set(storedNames, forKey: Self.scheduledNamesKey)
                if let oldFingerprint { defaults.set(oldFingerprint, forKey: Self.scheduleFingerprintKey) }
            }
            debugStore.log("Reprogramación fallida; recuperación=\(recovered ? "completa" : "incompleta") ritualesAntes=\(nativeRituals.count) ritualesAhora=\(remaining.filter { $0.hasPrefix(Self.ritualPrefix) }.count).")
            throw recovered ? originalError : SchedulingFailure.recoveryIncomplete
        }

        // All desired monitors now exist. Only remove obsolete ritual registrations.
        let obsolete = Set(storedNames).union(nativeRituals).subtracting(desiredNames)
        if !obsolete.isEmpty { await monitor.stop(obsolete.sorted()) }
        for name in obsolete {
            selectionStore.removeSelection(for: name)
            metadataStore.removeMetadata(for: name)
            activityStateStore.remove(activityName: name)
        }
        defaults.set(desiredNames.sorted(), forKey: Self.scheduledNamesKey)
        defaults.set(fingerprint, forKey: Self.scheduleFingerprintKey)
        debugStore.log("Programación confirmada rituales=\(schedulers.count) monitores=\(desiredNames.count) retirados=\(obsolete.count) auxiliares=\(otherCount).")
    }

    private func makePlan(_ schedulers: [RitualScheduler], userID: String?) throws -> [PlannedActivity] {
        var plan: [PlannedActivity] = []
        for (priority, scheduler) in schedulers.enumerated() where scheduler.selectedItemCount > 0 {
            guard scheduler.durationMinutes >= Self.minimumMonitorDurationMinutes else {
                debugStore.log("Ritual omitido de DeviceActivity: duración menor a 15 minutos.")
                continue
            }
            let weekdays = Set(scheduler.weekdays.filter { (1...7).contains($0) }).sorted()
            let daily = weekdays == Array(1...7)
            // Reuse Sunday's legacy name for daily schedules. This permits migrating
            // a full weekly registry without needing an extra slot for each ritual.
            for weekday in daily ? [1] : weekdays {
                let name = activityName(for: scheduler, weekday: weekday).rawValue
                let metadata = SharedRitualActivityMetadata(activityName: name, userID: userID,
                    schedulerId: scheduler.id.uuidString, coreRitualId: scheduler.coreRitualId,
                    title: scheduler.title, plannedEndAt: scheduler.endDate(),
                    endHour: scheduler.endHour, endMinute: scheduler.endMinute, priority: priority,
                    strictModeEnabled: scheduler.strictModeEnabled,
                    blockAppInstallation: scheduler.blockAppInstallation, blockAdultContent: scheduler.blockAdultContent)
                _ = try JSONEncoder().encode(scheduler.selection)
                _ = try JSONEncoder().encode(metadata)
                let endWeekday = scheduler.crossesMidnight ? (weekday % 7 + 1) : weekday
                let registration = RitualMonitorRegistration(
                    start: DateComponents(calendar: calendar, hour: scheduler.startHour,
                        minute: scheduler.startMinute, weekday: daily ? nil : weekday),
                    end: DateComponents(calendar: calendar, hour: scheduler.endHour,
                        minute: scheduler.endMinute, weekday: daily ? nil : endWeekday),
                    repeats: true, warning: DateComponents(minute: 2))
                plan.append(PlannedActivity(name: name, selection: scheduler.selection,
                    metadata: metadata, registration: registration))
            }
        }
        return plan
    }

    func stopMonitoringCurrentInterval(for scheduler: RitualScheduler, on date: Date = .now) {
        enqueue { await self.performStopCurrentInterval(for: scheduler) }
    }

    private func performStopCurrentInterval(for scheduler: RitualScheduler) async {
        let names = _scheduledNames(for: [scheduler])
        await stopMonitoring(names)

        let stoppedNames = names.map(\.rawValue)
        stoppedNames.forEach {
            selectionStore.removeSelection(for: $0)
            metadataStore.removeMetadata(for: $0)
            activityStateStore.remove(activityName: $0)
        }

        let storedNames = defaults.stringArray(forKey: Self.scheduledNamesKey) ?? []
        let remainingNames = storedNames.filter { !stoppedNames.contains($0) }
        defaults.set(remainingNames, forKey: Self.scheduledNamesKey)
        defaults.removeObject(forKey: Self.scheduleFingerprintKey)
        debugStore.log("Monitores pausados manualmente \(stoppedNames.count) para \(scheduler.title).")
    }

    func clearAll() {
        enqueue {
            await self.stopPreviouslyScheduledActivities()
            self.defaults.removeObject(forKey: Self.scheduleFingerprintKey)
        }
    }

    private func stopMonitoring(_ names: [DeviceActivityName]) async {
        guard !names.isEmpty else { return }
        await monitor.stop(names.map(\.rawValue))
    }

    private func stopPreviouslyScheduledActivities() async {
        defaults.removeObject(forKey: Self.scheduleFingerprintKey)
        let storedNames = defaults.stringArray(forKey: Self.scheduledNamesKey) ?? []
        let names = storedNames.map { DeviceActivityName($0) }
        await stopMonitoring(names)
        storedNames.forEach {
            selectionStore.removeSelection(for: $0)
            metadataStore.removeMetadata(for: $0)
        }
        activityStateStore.clear()
        if !storedNames.isEmpty {
            debugStore.log("Detenidos \(storedNames.count) monitores anteriores.")
        }
        defaults.removeObject(forKey: Self.scheduledNamesKey)
    }

    private func scheduleFingerprint(for schedulers: [RitualScheduler], userID: String?) throws -> String {
        let schedulerComponents = try schedulers
            .enumerated()
            .map { priority, scheduler -> String in
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let tokens = try scheduler.selection.applicationTokens.map { "app:" + (try encoder.encode($0)).base64EncodedString() }
                    + scheduler.selection.categoryTokens.map { "category:" + (try encoder.encode($0)).base64EncodedString() }
                    + scheduler.selection.webDomainTokens.map { "web:" + (try encoder.encode($0)).base64EncodedString() }
                let selectionData = Data(tokens.sorted().joined(separator: "|").utf8)
                let selectionHash = SHA256.hash(data: selectionData)
                    .map { String(format: "%02x", $0) }
                    .joined()

                return [
                    String(priority),
                    scheduler.id.uuidString,
                    scheduler.coreRitualId ?? "",
                    scheduler.title,
                    "\(scheduler.startHour):\(scheduler.startMinute)",
                    "\(scheduler.endHour):\(scheduler.endMinute)",
                    scheduler.weekdays.sorted().map(String.init).joined(separator: ","),
                    scheduler.strictModeEnabled ? "strict" : "standard",
                    scheduler.blockAppInstallation ? "block-install" : "allow-install",
                    scheduler.blockAdultContent ? "sensitive-web" : "standard-web",
                    selectionHash
                ].joined(separator: "|")
            }

        let components = ["daily-plan-v2", userID ?? ""] + schedulerComponents
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

nonisolated struct RitualMonitorRegistration: Equatable, Sendable {
    let start: DateComponents
    let end: DateComponents
    let repeats: Bool
    let warning: DateComponents?
}

/// DeviceActivity IPC may wait for the system service. Never run it on the UI thread.
nonisolated final class DeviceActivityMonitorExecutor: @unchecked Sendable {
    private let queue = DeviceActivityCommandQueue.shared

    func names() async -> Set<String> {
        await withCheckedContinuation { continuation in
            queue.submit {
                let span = AppDiagnostics.shared.begin("device_activity.list")
                let names = Set(DeviceActivityCenter().activities.map(\.rawValue))
                AppDiagnostics.shared.end("device_activity.list", span)
                continuation.resume(returning: names)
            }
        }
    }

    func registration(_ name: String) async -> RitualMonitorRegistration? {
        await withCheckedContinuation { continuation in
            queue.submit {
                let schedule = DeviceActivityCenter().schedule(for: DeviceActivityName(name))
                continuation.resume(returning: schedule.map {
                    RitualMonitorRegistration(start: $0.intervalStart, end: $0.intervalEnd,
                        repeats: $0.repeats, warning: $0.warningTime)
                })
            }
        }
    }

    func register(_ name: String, registration: RitualMonitorRegistration) async throws {
        try await start(name, schedule: DeviceActivitySchedule(intervalStart: registration.start,
            intervalEnd: registration.end, repeats: registration.repeats, warningTime: registration.warning))
    }

    func start(_ name: String, intervalStart: DateComponents, intervalEnd: DateComponents) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.submit {
                let span = AppDiagnostics.shared.begin("device_activity.start")
                defer { AppDiagnostics.shared.end("device_activity.start", span) }
                do {
                    let schedule = DeviceActivitySchedule(
                        intervalStart: intervalStart, intervalEnd: intervalEnd,
                        repeats: true, warningTime: DateComponents(minute: 2)
                    )
                    try DeviceActivityCenter().startMonitoring(DeviceActivityName(name), during: schedule)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func start(_ name: String, schedule: DeviceActivitySchedule) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.submit {
                let span = AppDiagnostics.shared.begin("device_activity.one_shot.start")
                defer { AppDiagnostics.shared.end("device_activity.one_shot.start", span) }
                do {
                    try DeviceActivityCenter().startMonitoring(DeviceActivityName(name), during: schedule)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func stop(_ names: [String]) async {
        // DeviceActivity interprets an empty list as "stop every activity".
        guard !names.isEmpty else { return }
        await withCheckedContinuation { continuation in
            queue.submit {
                let span = AppDiagnostics.shared.begin("device_activity.stop")
                DeviceActivityCenter().stopMonitoring(names.map { DeviceActivityName($0) })
                AppDiagnostics.shared.end("device_activity.stop", span)
                continuation.resume()
            }
        }
    }
}
