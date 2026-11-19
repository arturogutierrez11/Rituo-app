import Foundation

struct SharedActiveRitualActivity: Codable {
    let activityName: String
    let startedAt: Date

    // Anchor the end to this occurrence, never to today's date: a missed end
    // callback must not extend yesterday's ritual into the next occurrence.
    func hasExpired(endHour: Int?, endMinute: Int?, plannedEndAt: Date?,
                    now: Date = .now, calendar: Calendar = .current) -> Bool {
        if let hour = endHour, let minute = endMinute,
           (0...23).contains(hour), (0...59).contains(minute) {
            let end = calendar.nextDate(after: startedAt,
                matching: DateComponents(hour: hour, minute: minute, second: 0),
                matchingPolicy: .nextTime, repeatedTimePolicy: .first)
            return end.map { now >= $0 } ?? true
        }
        return plannedEndAt.map { now >= $0 } ?? true
    }
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

    // Persistent tombstone also rejects callbacks already queued when deleting.
    func markDeleted(schedulerID: String) {
        defaults?.set(true, forKey: "rituo.deletedScheduler." + schedulerID)
        defaults?.synchronize()
    }

    func restoreDeleted(schedulerID: String) {
        defaults?.removeObject(forKey: "rituo.deletedScheduler." + schedulerID)
        defaults?.synchronize()
    }

    func isDeleted(schedulerID: String) -> Bool {
        defaults?.bool(forKey: "rituo.deletedScheduler." + schedulerID) == true
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
