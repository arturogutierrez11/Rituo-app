import ActivityKit
import Foundation
import UIKit

struct FocusLiveActivityInput: Hashable {
    struct Entry: Hashable {
        var id: String
        var state: RituoFocusActivityAttributes.ContentState
    }
    var active: Entry?
    var upcoming: Entry?
}

enum FocusLiveActivitySyncState: Equatable {
    case waiting(accountID: String?)
    case signedOut
    case ready(FocusLiveActivityInput)

    static func resolve(isRestoring: Bool, authenticatedAccountID: String?,
                        restoredAccountID: String?, hasCheckedLegal: Bool,
                        canEnter: Bool, input: FocusLiveActivityInput) -> Self {
        guard !isRestoring else { return .waiting(accountID: nil) }
        guard let accountID = authenticatedAccountID else { return .signedOut }
        guard restoredAccountID == accountID, hasCheckedLegal, canEnter else {
            return .waiting(accountID: accountID)
        }
        return .ready(input)
    }
}

@MainActor
final class FocusLiveActivityService {
    static let shared = FocusLiveActivityService()
    private var pending: Task<Void, Never>?
    private var generation = 0
    // Respect dismissals: do not recreate the same occurrence on every refresh.
    private var requested = Set<String>()

    func synchronize(_ input: FocusLiveActivityInput) {
        enqueue { await self.apply(input) }
    }

    // Loading is not a sign-out. Keep this account's card until its state is
    // restored, while removing cards that belong to a confirmed previous account.
    func waitForSession(retainingAccountID accountID: String?) {
        enqueue {
            guard let accountID else { return }
            let prefix = accountID + ":"
            self.requested = self.requested.filter { $0.hasPrefix(prefix) }
            for activity in Activity<RituoFocusActivityAttributes>.activities
                where !activity.attributes.sessionID.hasPrefix(prefix) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        generation += 1
        let revision = generation
        let previous = pending
        pending = Task { @MainActor in
            await previous?.value
            guard revision == self.generation else { return }
            await operation()
        }
    }

    private func apply(_ input: FocusLiveActivityInput) async {
        let now = Date.now
        let entries = [input.active, input.upcoming].compactMap { $0 }.map { entry in
            var entry = entry
            if entry.state.startedAt == .distantPast {
                entry.state.startedAt = Activity<RituoFocusActivityAttributes>.activities
                    .first { $0.attributes.sessionID == entry.id }?.content.state.startedAt ?? now
            }
            return entry
        }
            .filter { $0.state.freshnessDeadline > now }
        let allowedIDs = Set(entries.map(\.id))
        requested.formIntersection(allowedIDs)
        for activity in Activity<RituoFocusActivityAttributes>.activities {
            guard allowedIDs.contains(activity.attributes.sessionID) else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
            guard let entry = entries.first(where: { $0.id == activity.attributes.sessionID }) else { continue }
            // Updating content does not change ActivityKit's registered start.
            // Only pending cards need replacement; a visible card can update in place.
            if #available(iOS 26.0, *), activity.activityState == .pending,
               activity.content.state.startedAt != entry.state.startedAt {
                await activity.end(nil, dismissalPolicy: .immediate)
                requested.remove(entry.id)
                continue
            }
            // A pending activity becomes visible at its date without app execution.
            if activity.content.state != entry.state {
                await activity.update(ActivityContent(state: entry.state, staleDate: entry.state.freshnessDeadline))
            }
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              UIApplication.shared.applicationState == .active else { return }
        for entry in entries {
            guard !Activity<RituoFocusActivityAttributes>.activities.contains(where: { $0.attributes.sessionID == entry.id }),
                  !requested.contains(entry.id) else { continue }
            let content = ActivityContent(state: entry.state, staleDate: entry.state.freshnessDeadline)
            do {
                if entry.state.startedAt > now {
                    if #available(iOS 26.0, *) {
                        _ = try Activity.request(attributes: RituoFocusActivityAttributes(sessionID: entry.id),
                            content: content, pushType: nil, style: .standard,
                            alertConfiguration: AlertConfiguration(title: "Tu ritual empieza", body: "Revisá tu tiempo de foco en Rituo.", sound: .default),
                            start: entry.state.startedAt)
                    } else { continue }
                } else {
                    _ = try Activity.request(attributes: RituoFocusActivityAttributes(sessionID: entry.id), content: content, pushType: nil)
                }
                requested.insert(entry.id)
            } catch {
                AppDiagnostics.shared.event("live_activity.request_failed code=\((error as NSError).code)")
            }
        }
    }
}
