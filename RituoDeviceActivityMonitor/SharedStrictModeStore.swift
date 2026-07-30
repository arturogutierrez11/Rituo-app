import Foundation

struct SharedStrictModeStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let enabledUserIDsKey = "rituo.strictMode.enabledUserIDs"

    private let defaults: UserDefaults?

    init() {
        defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func isEnabled(userID: String?) -> Bool {
        guard let userID, !userID.isEmpty else { return false }
        let enabledUserIDs = defaults?.stringArray(forKey: Self.enabledUserIDsKey) ?? []
        return enabledUserIDs.contains(userID)
    }
}

struct SharedSensitiveWebContentBlockStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let enabledUserIDsKey = "rituo.sensitiveWebContentBlock.enabledUserIDs"

    private let defaults: UserDefaults?

    init() {
        defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func isEnabled(userID: String?) -> Bool {
        guard let userID, !userID.isEmpty else { return false }
        let enabledUserIDs = defaults?.stringArray(forKey: Self.enabledUserIDsKey) ?? []
        return enabledUserIDs.contains(userID)
    }

    var isEnabledForAnyUser: Bool {
        !(defaults?.stringArray(forKey: Self.enabledUserIDsKey) ?? []).isEmpty
    }
}
