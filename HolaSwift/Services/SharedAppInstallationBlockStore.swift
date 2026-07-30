import Foundation

struct SharedAppInstallationBlockStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let enabledUserIDsKey = "rituo.appInstallationBlock.enabledUserIDs"

    private let defaults: UserDefaults?

    init() {
        defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func isEnabled(userID: String?) -> Bool {
        guard let userID, !userID.isEmpty else { return false }
        return enabledUserIDs.contains(userID)
    }

    func setEnabled(_ isEnabled: Bool, userID: String) {
        var userIDs = enabledUserIDs
        if isEnabled {
            userIDs.insert(userID)
        } else {
            userIDs.remove(userID)
        }
        defaults?.set(Array(userIDs), forKey: Self.enabledUserIDsKey)
    }

    func remove(userID: String) {
        setEnabled(false, userID: userID)
    }

    private var enabledUserIDs: Set<String> {
        Set(defaults?.stringArray(forKey: Self.enabledUserIDsKey) ?? [])
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
        return enabledUserIDs.contains(userID)
    }

    func setEnabled(_ isEnabled: Bool, userID: String) {
        var userIDs = enabledUserIDs
        if isEnabled {
            userIDs.insert(userID)
        } else {
            userIDs.remove(userID)
        }
        defaults?.set(Array(userIDs), forKey: Self.enabledUserIDsKey)
    }

    func remove(userID: String) {
        setEnabled(false, userID: userID)
    }

    private var enabledUserIDs: Set<String> {
        Set(defaults?.stringArray(forKey: Self.enabledUserIDsKey) ?? [])
    }
}
