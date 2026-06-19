import Foundation

struct SharedRitualActivityMetadata: Codable {
    let activityName: String
    let schedulerId: String
    let coreRitualId: String?
    let title: String
    let plannedEndAt: Date?
}

struct SharedRitualActivityMetadataStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let keyPrefix = "rituo.deviceActivity.metadata."

    private let defaults: UserDefaults?

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func save(metadata: SharedRitualActivityMetadata, for activityName: String) throws {
        let data = try JSONEncoder().encode(metadata)
        defaults?.set(data, forKey: Self.keyPrefix + activityName)
    }

    func loadMetadata(for activityName: String) -> SharedRitualActivityMetadata? {
        guard let data = defaults?.data(forKey: Self.keyPrefix + activityName) else {
            return nil
        }

        return try? JSONDecoder().decode(SharedRitualActivityMetadata.self, from: data)
    }

    func removeMetadata(for activityName: String) {
        defaults?.removeObject(forKey: Self.keyPrefix + activityName)
    }
}
