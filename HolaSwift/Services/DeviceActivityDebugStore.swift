import Foundation

struct DeviceActivityDebugStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let eventsKey = "rituo.deviceActivity.debugEvents"

    private let defaults: UserDefaults?

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func log(_ message: @autoclosure () -> String) {
        let message = message()
        guard let defaults else { return }

        var events = defaults.stringArray(forKey: Self.eventsKey) ?? []
        events.insert("\(Self.timestamp()) [\(Bundle.main.bundleIdentifier ?? "unknown")] \(message)", at: 0)
        defaults.set(Array(events.prefix(256)), forKey: Self.eventsKey)
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
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
        return formatter.string(from: .now)
    }
}
