import ActivityKit
import Foundation

nonisolated struct RituoFocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var startedAt: Date
        var endsAt: Date?
        var breakStartedAt: Date?
        var breakEndsAt: Date?
        var scheduled: Bool

        var freshnessDeadline: Date {
            [endsAt, breakEndsAt, startedAt.addingTimeInterval(8 * 3600)].compactMap { $0 }.min()!
        }
    }
    var sessionID: String
}
