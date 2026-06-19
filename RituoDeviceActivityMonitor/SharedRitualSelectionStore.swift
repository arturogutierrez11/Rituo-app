import FamilyControls
import Foundation

struct SharedRitualSelectionStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let keyPrefix = "rituo.deviceActivity.selection."

    private let defaults: UserDefaults?

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func save(selection: FamilyActivitySelection, for activityName: String) throws {
        let data = try JSONEncoder().encode(selection)
        defaults?.set(data, forKey: Self.keyPrefix + activityName)
    }

    func loadSelection(for activityName: String) -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: Self.keyPrefix + activityName) else {
            return nil
        }

        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func removeSelection(for activityName: String) {
        defaults?.removeObject(forKey: Self.keyPrefix + activityName)
    }
}
