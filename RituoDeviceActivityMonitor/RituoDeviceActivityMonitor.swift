import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class RituoDeviceActivityMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()
    private let selectionStore = SharedRitualSelectionStore()
    private let metadataStore = SharedRitualActivityMetadataStore()
    private let eventStore = SharedRitualActivityEventStore()
    private let debugStore = DeviceActivityDebugStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        debugStore.log("intervalDidStart \(activity.rawValue).")

        guard let selection = selectionStore.loadSelection(for: activity.rawValue) else {
            debugStore.log("Sin selection para \(activity.rawValue).")
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens, except: [])
        }

        let itemCount = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        appendEvent(type: "started", activity: activity)
        debugStore.log("Shield aplicado items=\(itemCount).")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        debugStore.log("intervalDidEnd \(activity.rawValue).")
        store.clearAllSettings()
        appendEvent(type: "ended", activity: activity)
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        debugStore.log("intervalWillStartWarning \(activity.rawValue).")
    }

    private func appendEvent(type: String, activity: DeviceActivityName) {
        guard let metadata = metadataStore.loadMetadata(for: activity.rawValue) else {
            debugStore.log("Sin metadata para evento \(type) \(activity.rawValue).")
            return
        }

        eventStore.append(
            event: SharedRitualActivityEvent(
                id: UUID(),
                activityName: activity.rawValue,
                eventType: type,
                occurredAt: Date(),
                schedulerId: metadata.schedulerId,
                coreRitualId: metadata.coreRitualId,
                title: metadata.title,
                plannedEndAt: metadata.plannedEndAt
            )
        )
        debugStore.log("Evento DeviceActivity \(type) guardado para \(metadata.title).")
    }
}
