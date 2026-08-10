import Foundation

struct SharedActiveRitualActivity: Codable {
    let activityName: String
    let startedAt: Date
}

/// Persists active DeviceActivity intervals across extension invocations so an
/// overlapping ritual can take over without requiring the main app to open.
struct SharedRitualActivityStateStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let activeActivitiesKey =
        "rituo.deviceActivity.activeRitualActivities"

    private let defaults: UserDefaults?

    init() {
        defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func markActive(activityName: String, startedAt: Date = .now) {
        var activities = activeActivities().filter {
            $0.activityName != activityName
        }
        activities.append(
            SharedActiveRitualActivity(
                activityName: activityName,
                startedAt: startedAt
            )
        )
        save(activities)
    }

    func remove(activityName: String) {
        save(
            activeActivities().filter { $0.activityName != activityName }
        )
    }

    func activeActivities() -> [SharedActiveRitualActivity] {
        defaults?.synchronize()
        guard let data = defaults?.data(forKey: Self.activeActivitiesKey) else {
            return []
        }

        return (try? JSONDecoder().decode(
            [SharedActiveRitualActivity].self,
            from: data
        )) ?? []
    }

    func clear() {
        defaults?.removeObject(forKey: Self.activeActivitiesKey)
        defaults?.synchronize()
    }

    private func save(_ activities: [SharedActiveRitualActivity]) {
        guard let defaults else { return }
        if activities.isEmpty {
            defaults.removeObject(forKey: Self.activeActivitiesKey)
        } else if let data = try? JSONEncoder().encode(activities) {
            defaults.set(data, forKey: Self.activeActivitiesKey)
        }
        defaults.synchronize()
    }
}
