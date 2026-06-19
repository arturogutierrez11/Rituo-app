import Foundation

struct DeviceActivityDebugStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let eventsKey = "rituo.deviceActivity.debugEvents"

    private let defaults: UserDefaults?

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func log(_ message: String) {
        guard let defaults else { return }

        var events = defaults.stringArray(forKey: Self.eventsKey) ?? []
        events.insert("\(Self.timestamp())  \(message)", at: 0)
        defaults.set(Array(events.prefix(24)), forKey: Self.eventsKey)
    }

    func latestEvents(limit: Int = 8) -> [String] {
        let events = defaults?.stringArray(forKey: Self.eventsKey) ?? []
        return Array(events.prefix(limit))
    }

    func clear() {
        defaults?.removeObject(forKey: Self.eventsKey)
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: .now)
    }
}
