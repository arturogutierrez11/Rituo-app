import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

private extension ManagedSettingsStore.Name {
    static let rituo = Self("rituo")
    static let rituoMode = Self("rituo.mode")
    static let rituoStrictScheduled = Self("rituo.strict.scheduled")
    static let rituoSensitiveWebGlobal = Self("rituo.sensitiveWeb.global")
}

final class RituoDeviceActivityMonitor: DeviceActivityMonitor {
    private static let modeBreakEndActivityPrefix = "rituo.modeBreakEnd."

    private let center = DeviceActivityCenter()
    private let store = ManagedSettingsStore(named: .rituo)
    private let modeStore = ManagedSettingsStore(named: .rituoMode)
    private let strictStore = ManagedSettingsStore(named: .rituoStrictScheduled)
    private let sensitiveWebGlobalStore = ManagedSettingsStore(named: .rituoSensitiveWebGlobal)
    private let legacyStore = ManagedSettingsStore()
    private let selectionStore = SharedRitualSelectionStore()
    private let metadataStore = SharedRitualActivityMetadataStore()
    private let eventStore = SharedRitualActivityEventStore()
    private let suppressionStore = SharedRitualSuppressionStore()
    private let strictModeStore = SharedStrictModeStore()
    private let sensitiveWebContentBlockStore = SharedSensitiveWebContentBlockStore()
    private let debugStore = DeviceActivityDebugStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        debugStore.log("intervalDidStart \(activity.rawValue).")

        if isModeBreakEndActivity(activity) {
            clearModeStores()
            debugStore.log("Recreo de modo iniciado por DeviceActivity \(activity.rawValue).")
            return
        }

        guard let metadata = metadataStore.loadMetadata(for: activity.rawValue) else {
            clearStrictModeRestriction()
            updateSensitiveWebContentBlocking(contextEnabled: false)
            debugStore.log("Sin metadata para \(activity.rawValue).")
            return
        }

        let preemptedMode = suppressionStore.isModeActive()
        if preemptedMode {
            suppressionStore.setModeActive(false)
            cancelModeBreakForPreemption()
            clearModeStores()
            debugStore.log("Modo activo interrumpido por el ritual \(metadata.title).")
        }

        if suppressionStore.isSuppressed(schedulerId: metadata.schedulerId) {
            clear(store: store)
            clear(store: legacyStore)
            clearStrictModeRestriction()
            updateSensitiveWebContentBlocking(
                contextEnabled: false,
                userID: metadata.userID
            )
            debugStore.log("Inicio ignorado por supresion activa para \(metadata.title).")
            return
        }

        guard let selection = selectionStore.loadSelection(for: activity.rawValue) else {
            clearStrictModeRestriction()
            updateSensitiveWebContentBlocking(
                contextEnabled: false,
                userID: metadata.userID
            )
            debugStore.log("Sin selection para \(activity.rawValue).")
            return
        }

        clear(store: legacyStore)
        clear(store: store)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens, except: [])
        }

        store.application.denyAppInstallation = metadata.blockAppInstallation ? true : nil
        store.webContent.blockedByFilter = metadata.blockAdultContent
            ? .auto(SensitiveWebDomainCatalog.blockedDomains)
            : nil
        updateSensitiveWebContentBlocking(
            contextEnabled: metadata.blockAdultContent,
            userID: metadata.userID
        )

        strictStore.application.denyAppRemoval = (
            metadata.strictModeEnabled ||
            strictModeStore.isEnabled(userID: metadata.userID)
        )
            ? true
            : nil

        let itemCount = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        if preemptedMode {
            appendEvent(type: "mode_preempted", activity: activity)
        }
        sendRitualStartedNotification(metadata)
        appendEvent(type: "started", activity: activity)
        debugStore.log(
            "Shield aplicado items=\(itemCount) strict=\(metadata.strictModeEnabled) blockInstall=\(metadata.blockAppInstallation)."
        )
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        debugStore.log("intervalDidEnd \(activity.rawValue).")

        if isModeBreakEndActivity(activity) {
            finishModeBreakActivity(activity, source: "end")
            return
        }

        clear(store: store)
        clear(store: legacyStore)
        clearStrictModeRestriction()
        if !suppressionStore.isModeActive() {
            updateSensitiveWebContentBlocking(contextEnabled: false)
        }
        appendEvent(type: "ended", activity: activity)
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        debugStore.log("intervalWillStartWarning \(activity.rawValue).")
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        debugStore.log("intervalWillEndWarning \(activity.rawValue).")

        if isModeBreakEndActivity(activity) {
            finishModeBreakActivity(activity, source: "warning")
        }
    }

    private func clear(store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.webDomains = nil
        store.shield.applicationCategories = nil
        store.clearAllSettings()
    }

    private func clearModeStores() {
        clear(store: modeStore)
        updateSensitiveWebContentBlocking(contextEnabled: false)
    }

    private func cancelModeBreakForPreemption() {
        guard let storedName = suppressionStore.takeModeBreakActivityName() else {
            return
        }

        let activity = DeviceActivityName(storedName)
        center.stopMonitoring([activity])
        selectionStore.removeSelection(for: storedName)
        metadataStore.removeMetadata(for: storedName)
        debugStore.log("Recreo de modo cancelado por prioridad de ritual \(storedName).")
    }

    private func apply(_ selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        // Force Screen Time to refresh the shield presentation even when a
        // mode is reactivated with exactly the same selection.
        store.clearAllSettings()
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens, except: [])
        }
    }

    private func applyMode(
        _ selection: FamilyActivitySelection,
        blockAppInstallation: Bool,
        blockAdultContent: Bool
    ) {
        apply(selection, to: modeStore)
        modeStore.application.denyAppInstallation = blockAppInstallation ? true : nil
        modeStore.webContent.blockedByFilter = blockAdultContent
            ? .auto(SensitiveWebDomainCatalog.blockedDomains)
            : nil
        updateSensitiveWebContentBlocking(contextEnabled: blockAdultContent)
    }

    private func isModeBreakEndActivity(_ activity: DeviceActivityName) -> Bool {
        activity.rawValue.hasPrefix(Self.modeBreakEndActivityPrefix)
    }

    private func finishModeBreakActivity(
        _ activity: DeviceActivityName,
        source: String
    ) {
        restoreModeShieldAfterBreak(activity)
        sendModeBreakEndedNotification(activity)
        selectionStore.removeSelection(for: activity.rawValue)
        metadataStore.removeMetadata(for: activity.rawValue)
        center.stopMonitoring([activity])
        _ = suppressionStore.takeModeBreakActivityName()
        debugStore.log("Fin de recreo de modo procesado por \(source) \(activity.rawValue).")
    }

    private func restoreModeShieldAfterBreak(_ activity: DeviceActivityName) {
        guard let selection = selectionStore.loadSelection(for: activity.rawValue) else {
            debugStore.log("Sin selection para fin de recreo \(activity.rawValue).")
            return
        }

        let metadata = metadataStore.loadMetadata(for: activity.rawValue)
        applyMode(
            selection,
            blockAppInstallation: metadata?.blockAppInstallation ?? false,
            blockAdultContent: metadata?.blockAdultContent ?? false
        )
        let itemCount = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        debugStore.log("Shield de modo reaplicado tras recreo items=\(itemCount) blockInstall=\(metadata?.blockAppInstallation ?? false) adultContent=\(metadata?.blockAdultContent ?? false).")
    }

    private func sendModeBreakEndedNotification(_ activity: DeviceActivityName) {
        let metadata = metadataStore.loadMetadata(for: activity.rawValue)
        let title = metadata?.title ?? "Tu modo"
        let identifier = metadata.map {
            "rituo.mode.break.ended.\($0.schedulerId)"
        } ?? "rituo.mode.break.extension.ended.\(activity.rawValue)"

        let content = UNMutableNotificationContent()
        content.title = "Recreo terminado"
        content.body = "\(title) volvió a aplicar tus restricciones."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request) { [debugStore] error in
            if let error {
                debugStore.log("Error notificación extension fin recreo: \(error.localizedDescription).")
            } else {
                debugStore.log("Notificación extension fin recreo enviada para \(title).")
            }
        }
    }

    private func sendRitualStartedNotification(
        _ metadata: SharedRitualActivityMetadata
    ) {
        let identifier = "rituo.ritual.started.\(metadata.schedulerId)"
        let content = UNMutableNotificationContent()
        content.title = "Tu ritual empezó"

        if let endHour = metadata.endHour,
           let endMinute = metadata.endMinute {
            content.body = "\(metadata.title) está activo. Tus apps seleccionadas quedan en pausa hasta las \(String(format: "%02d:%02d", endHour, endMinute))."
        } else {
            content.body = "\(metadata.title) está activo. Tus apps seleccionadas quedaron en pausa."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: [identifier]
        )
        notificationCenter.add(request) { [debugStore] error in
            if let error {
                debugStore.log(
                    "Error notificación inicio ritual \(metadata.title): \(error.localizedDescription)."
                )
            } else {
                debugStore.log(
                    "Notificación inicio ritual enviada por extensión para \(metadata.title)."
                )
            }
        }
    }

    private func clearStrictModeRestriction() {
        strictStore.application.denyAppRemoval = nil
    }

    private func updateSensitiveWebContentBlocking(
        contextEnabled: Bool,
        userID: String? = nil
    ) {
        let globalEnabled = userID.map {
            sensitiveWebContentBlockStore.isEnabled(userID: $0)
        } ?? sensitiveWebContentBlockStore.isEnabledForAnyUser
        sensitiveWebGlobalStore.webContent.blockedByFilter = globalEnabled
            ? .auto(SensitiveWebDomainCatalog.blockedDomains)
            : nil
        SafariContentBlockerController.setBlockingEnabled(
            globalEnabled || contextEnabled
        )
    }

    private func appendEvent(type: String, activity: DeviceActivityName) {
        guard let metadata = metadataStore.loadMetadata(for: activity.rawValue) else {
            debugStore.log("Sin metadata para evento \(type) \(activity.rawValue).")
            return
        }

        eventStore.append(
            event: SharedRitualActivityEvent(
                id: UUID(),
                userID: metadata.userID,
                activityName: activity.rawValue,
                eventType: type,
                occurredAt: Date(),
                schedulerId: metadata.schedulerId,
                coreRitualId: metadata.coreRitualId,
                title: metadata.title,
                plannedEndAt: plannedEndDate(for: metadata)
            )
        )
        debugStore.log("Evento DeviceActivity \(type) guardado para \(metadata.title).")
    }

    private func plannedEndDate(
        for metadata: SharedRitualActivityMetadata,
        now: Date = .now
    ) -> Date? {
        guard let endHour = metadata.endHour,
              let endMinute = metadata.endMinute else {
            return metadata.plannedEndAt
        }

        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: now
        )
        components.hour = endHour
        components.minute = endMinute
        components.second = 0
        return Calendar.current.date(from: components)
    }
}
