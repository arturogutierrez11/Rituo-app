import Foundation

struct SharedRitualActivityEvent: Codable, Identifiable {
    let id: UUID
    let userID: String?
    let activityName: String
    let eventType: String
    let occurredAt: Date
    let schedulerId: String
    let coreRitualId: String?
    let title: String
    let plannedEndAt: Date?
}

struct SharedRitualActivityEventStore {
    private static let appGroupIdentifier = "group.io.rituo.app"
    private static let eventsKey = "rituo.deviceActivity.pendingEvents"

    private let defaults: UserDefaults?

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupIdentifier)
    }

    func append(event: SharedRitualActivityEvent) {
        var events = loadEvents()
        let duplicateWindow: TimeInterval = 5 * 60
        let isDuplicate = events.contains { existing in
            existing.activityName == event.activityName &&
            existing.eventType == event.eventType &&
            abs(existing.occurredAt.timeIntervalSince(event.occurredAt)) < duplicateWindow
        }
        guard !isDuplicate else { return }

        events.append(event)
        save(events: Array(events.suffix(100)))
    }

    func loadEvents() -> [SharedRitualActivityEvent] {
        guard let data = defaults?.data(forKey: Self.eventsKey) else {
            return []
        }

        return (try? JSONDecoder().decode([SharedRitualActivityEvent].self, from: data)) ?? []
    }

    func removeEvents(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        save(events: loadEvents().filter { !ids.contains($0.id) })
    }

    private func save(events: [SharedRitualActivityEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults?.set(data, forKey: Self.eventsKey)
    }
}
