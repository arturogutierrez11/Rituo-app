import Foundation

/// Coordinates ritual notifications emitted by the app and the DeviceActivity
/// extension so the same ritual occurrence is delivered only once.
struct SharedRitualNotificationDeliveryStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let startNotificationExpirationsKey =
        "rituo.ritual.notifications.startExpirations"

    private let defaults: UserDefaults?

    init() {
        defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func claimStartNotification(
        schedulerId: String,
        validUntil: Date?,
        now: Date = .now
    ) -> Bool {
        guard let defaults else {
            // Notification delivery should keep working if the App Group is
            // temporarily unavailable.
            return true
        }

        defaults.synchronize()
        var expirations = defaults.dictionary(
            forKey: Self.startNotificationExpirationsKey
        ) as? [String: TimeInterval] ?? [:]

        expirations = expirations.filter { $0.value > now.timeIntervalSince1970 }
        if let expiration = expirations[schedulerId],
           expiration > now.timeIntervalSince1970 {
            return false
        }

        let minimumExpiration = now.addingTimeInterval(60)
        let expiration = max(validUntil ?? minimumExpiration, minimumExpiration)
        expirations[schedulerId] = expiration.timeIntervalSince1970
        defaults.set(expirations, forKey: Self.startNotificationExpirationsKey)
        defaults.synchronize()
        return true
    }
}
