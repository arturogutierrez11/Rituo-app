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

    func replaceSuppressions(_ suppressions: [UUID: Date]) {
        let values = Dictionary(
            uniqueKeysWithValues: suppressions.map { schedulerId, endDate in
                (schedulerId.uuidString, endDate.timeIntervalSince1970)
            }
        )
        defaults?.set(values, forKey: Self.suppressionsKey)
    }

    func setModeActive(_ isActive: Bool) {
        defaults?.set(isActive, forKey: Self.modeActiveKey)
    }

    func isModeActive() -> Bool {
        defaults?.bool(forKey: Self.modeActiveKey) ?? false
    }

    func setModeBreakActivityName(_ name: String?) {
        if let name {
            defaults?.set(name, forKey: Self.modeBreakActivityNameKey)
        } else {
            defaults?.removeObject(forKey: Self.modeBreakActivityNameKey)
        }
    }

    func modeBreakActivityName() -> String? {
        defaults?.string(forKey: Self.modeBreakActivityNameKey)
    }

    func isSuppressed(schedulerId: String, at date: Date = .now) -> Bool {
        guard let values = defaults?.dictionary(forKey: Self.suppressionsKey),
              let timestamp = values[schedulerId] as? TimeInterval else {
            return false
        }

        return Date(timeIntervalSince1970: timestamp) > date
    }
}
