import FamilyControls
import Foundation
import ManagedSettings

private extension ManagedSettingsStore.Name {
    static let rituo = Self("rituo")
    static let rituoMode = Self("rituo.mode")
    static let rituoStrictInteractive = Self("rituo.strict.interactive")
    static let rituoStrictScheduled = Self("rituo.strict.scheduled")
    static let rituoAppInstallation = Self("rituo.appInstallation")
    static let rituoSensitiveWebGlobal = Self("rituo.sensitiveWeb.global")
}

final class AppBlocker {
    private let store = ManagedSettingsStore(named: .rituo)
    private let modeStore = ManagedSettingsStore(named: .rituoMode)
    private let strictInteractiveStore = ManagedSettingsStore(named: .rituoStrictInteractive)
    private let strictScheduledStore = ManagedSettingsStore(named: .rituoStrictScheduled)
    private let appInstallationStore = ManagedSettingsStore(named: .rituoAppInstallation)
    private let sensitiveWebGlobalStore = ManagedSettingsStore(named: .rituoSensitiveWebGlobal)
    private let legacyStore = ManagedSettingsStore()

    func applyShield(
        using selection: FamilyActivitySelection,
        blockAppInstallation: Bool = false,
        blockAdultContent: Bool = false
    ) {
        clear(store: legacyStore)
        apply(selection, to: store)
        store.application.denyAppInstallation = blockAppInstallation ? true : nil
        store.webContent.blockedByFilter = blockAdultContent
            ? .auto(SensitiveWebDomainCatalog.blockedDomains)
            : nil
    }

    func applyModeShield(
        using selection: FamilyActivitySelection,
        blockAppInstallation: Bool = false,
        blockAdultContent: Bool = false
    ) {
        apply(selection, to: modeStore)
        modeStore.application.denyAppInstallation = blockAppInstallation ? true : nil
        modeStore.webContent.blockedByFilter = blockAdultContent
            ? .auto(SensitiveWebDomainCatalog.blockedDomains)
            : nil
    }

    func clearModeShield() {
        clear(store: modeStore)
    }

    func refreshSafariContentBlocking(isEnabled: Bool) {
        SafariContentBlockerController.setBlockingEnabled(isEnabled)
    }

    func clearShield() {
        clear(store: store)
        clear(store: legacyStore)
    }

    func clearAllShields() {
        clearShield()
        clearModeShield()
    }

    func setInteractiveStrictModeActive(_ isActive: Bool) {
        strictInteractiveStore.application.denyAppRemoval = isActive ? true : nil
    }

    func clearAllStrictModeRestrictions() {
        strictInteractiveStore.application.denyAppRemoval = nil
        strictScheduledStore.application.denyAppRemoval = nil
    }

    func setAppInstallationBlockingActive(_ isActive: Bool) {
        appInstallationStore.application.denyAppInstallation = isActive ? true : nil
    }

    func clearAppInstallationBlocking() {
        appInstallationStore.application.denyAppInstallation = nil
    }

    func setSensitiveWebContentBlockingActive(_ isActive: Bool) {
        sensitiveWebGlobalStore.webContent.blockedByFilter = isActive
            ? .auto(SensitiveWebDomainCatalog.blockedDomains)
            : nil
    }

    func clearSensitiveWebContentBlocking() {
        sensitiveWebGlobalStore.webContent.blockedByFilter = nil
    }

    private func apply(_ selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        // Replacing an already active selection with the same tokens may leave
        // Screen Time's previous shield presentation cached. Reset the store
        // first so the system asks our ShieldConfiguration extension again.
        store.clearAllSettings()
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens, except: [])
        }
    }

    private func clear(store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.webDomains = nil
        store.shield.applicationCategories = nil
        store.clearAllSettings()
    }
}
