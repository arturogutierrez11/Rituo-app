import Foundation

struct ProtectionOnboardingStore {
    static let currentVersion = 1

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isCompleted(userID: String) -> Bool {
        defaults.integer(forKey: key(userID: userID)) >= Self.currentVersion
    }

    func markCompleted(userID: String) {
        defaults.set(Self.currentVersion, forKey: key(userID: userID))
    }

    private func key(userID: String) -> String {
        "rituo.protectionOnboarding.version.\(userID)"
    }
}
