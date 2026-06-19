import FamilyControls
import Foundation
import ManagedSettings

final class AppBlocker {
    private let store = ManagedSettingsStore()

    func applyShield(using selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens, except: [])
        }
    }

    func clearShield() {
        store.clearAllSettings()
    }
}
