import FamilyControls
import Foundation

struct SharedActiveModeSnapshot: Codable {
    let userID: String?
    let modeID: String
    let coreModeID: String?
    let title: String
    let selection: FamilyActivitySelection
    let strictModeEnabled: Bool
    let blockAppInstallation: Bool
    let blockAdultContent: Bool
}

struct SharedActiveModeSnapshotStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let snapshotKey = "rituo.activeMode.sharedSnapshot"

    private let defaults: UserDefaults?

    init() {
        defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func load() -> SharedActiveModeSnapshot? {
        defaults?.synchronize()
        guard let data = defaults?.data(forKey: Self.snapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(
            SharedActiveModeSnapshot.self,
            from: data
        )
    }

    func clear() {
        defaults?.removeObject(forKey: Self.snapshotKey)
        defaults?.synchronize()
    }
}
