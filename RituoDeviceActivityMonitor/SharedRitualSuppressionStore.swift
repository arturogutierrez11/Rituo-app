import Foundation

struct SharedRitualSuppressionStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let suppressionsKey = "rituo.sharedScheduledBlockSuppressions"
    private static let modeActiveKey = "rituo.sharedModeActive"
    private static let modeBreakActivityNameKey = "rituo.sharedModeBreakActivityName"

    private let defaults: UserDefaults?

    init() {
        defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func isModeActive() -> Bool {
        defaults?.bool(forKey: Self.modeActiveKey) ?? false
    }

    func setModeActive(_ isActive: Bool) {
        defaults?.set(isActive, forKey: Self.modeActiveKey)
    }

    func takeModeBreakActivityName() -> String? {
        let name = defaults?.string(forKey: Self.modeBreakActivityNameKey)
        defaults?.removeObject(forKey: Self.modeBreakActivityNameKey)
        return name
    }

    func isSuppressed(schedulerId: String, at date: Date = .now) -> Bool {
        guard let values = defaults?.dictionary(forKey: Self.suppressionsKey),
              let timestamp = values[schedulerId] as? TimeInterval else {
            return false
        }

        return Date(timeIntervalSince1970: timestamp) > date
    }
}
