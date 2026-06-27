import FamilyControls
import Foundation
import ManagedSettings

private extension ManagedSettingsStore.Name {
    static let rituo = Self("rituo")
}

final class AppBlocker {
    private let store = ManagedSettingsStore(named: .rituo)
    private let legacyStore = ManagedSettingsStore()

    func applyShield(using selection: FamilyActivitySelection) {
        clear(store: legacyStore)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens, except: [])
        }
    }

    func clearShield() {
        clear(store: store)
        clear(store: legacyStore)
    }

    private func clear(store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.webDomains = nil
        store.shield.applicationCategories = nil
        store.clearAllSettings()
    }
}
