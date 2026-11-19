#!/usr/bin/env python3
"""Run the production coordinator against a deterministic ActivityKit adapter."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
service = (root / 'HolaSwift/Services/FocusLiveActivityService.swift').read_text()
service = service.replace('import ActivityKit\n', '').replace('import UIKit\n', '').replace('Activity<RituoFocusActivityAttributes>', 'FakeActivity').replace('Activity.request', 'FakeActivity.request')
source = r'''
import Foundation
struct RituoFocusActivityAttributes {
    struct ContentState: Hashable {
        var title: String; var startedAt: Date; var endsAt: Date?
        var breakStartedAt: Date?; var breakEndsAt: Date?; var scheduled: Bool
        var freshnessDeadline: Date { [endsAt, breakEndsAt, startedAt.addingTimeInterval(28800)].compactMap { $0 }.min()! }
    }
    var sessionID: String
}
struct ActivityContent { var state: RituoFocusActivityAttributes.ContentState; var staleDate: Date? }
enum ActivityStyle { case standard }
enum ActivityState { case pending, active, ended }
enum DismissalPolicy { case immediate }
enum Sound { case `default` }
struct AlertConfiguration { var title: String; var body: String; var sound: Sound }
@MainActor final class UIApplication {
    enum State { case active, background }
    static let shared = UIApplication()
    var applicationState = State.active
}
@MainActor struct ActivityAuthorizationInfo {
    static var enabled = true
    var areActivitiesEnabled: Bool { Self.enabled }
}
@MainActor final class AppDiagnostics {
    static let shared = AppDiagnostics()
    func event(_ value: String) {}
}
@MainActor final class FakeActivity {
    static var activities: [FakeActivity] = []
    static var starts = 0
    var scheduledStart: Date?
    var activityState = ActivityState.active
    let attributes: RituoFocusActivityAttributes
    var content: ActivityContent
    init(attributes: RituoFocusActivityAttributes, content: ActivityContent) { self.attributes = attributes; self.content = content }
    static func request(attributes: RituoFocusActivityAttributes, content: ActivityContent, pushType: Int?, style: ActivityStyle = .standard, alertConfiguration: AlertConfiguration? = nil, start: Date? = nil) throws -> FakeActivity {
        let activity = FakeActivity(attributes: attributes, content: content)
        activity.scheduledStart = start
        activity.activityState = start == nil ? .active : .pending
        activities.append(activity); starts += 1; return activity
    }
    func update(_ content: ActivityContent) async { self.content = content }
    func end(_ content: ActivityContent?, dismissalPolicy: DismissalPolicy) async { activityState = .ended; Self.activities.removeAll { $0 === self } }
}
''' + service + r'''
@main struct Tests {
    @MainActor static func main() async {
        let service = FocusLiveActivityService()
        let start = Date.now
        let state = RituoFocusActivityAttributes.ContentState(title: "Focus", startedAt: start,
            endsAt: start.addingTimeInterval(3600), breakStartedAt: nil, breakEndsAt: nil, scheduled: false)
        var entry = FocusLiveActivityInput.Entry(id: "accountA:occurrence", state: state)
        func drain() async { for _ in 0..<100 { await Task.yield() } }
        service.synchronize(.init(active: entry, upcoming: nil)); await drain()
        precondition(FakeActivity.starts == 1 && FakeActivity.activities.count == 1)
        service.synchronize(.init(active: entry, upcoming: nil)); await drain()
        precondition(FakeActivity.starts == 1)
        entry.state.breakStartedAt = start; entry.state.breakEndsAt = start.addingTimeInterval(300)
        service.synchronize(.init(active: entry, upcoming: nil)); await drain()
        precondition(FakeActivity.activities[0].content.state.breakEndsAt == entry.state.breakEndsAt)
        // A user dismissing the card must not trigger immediate recreation.
        FakeActivity.activities = []
        service.synchronize(.init(active: entry, upcoming: nil)); await drain()
        precondition(FakeActivity.starts == 1)
        // Sign-out retires the occurrence; another account gets a clean activity.
        service.synchronize(.init(active: nil, upcoming: nil)); await drain()
        entry.id = "accountB:occurrence"
        service.synchronize(.init(active: entry, upcoming: nil)); await drain()
        precondition(FakeActivity.starts == 2)
        UIApplication.shared.applicationState = .background
        service.synchronize(.init(active: nil, upcoming: nil)); await drain()
        precondition(FakeActivity.activities.isEmpty)
        service.synchronize(.init(active: entry, upcoming: nil)); await drain()
        precondition(FakeActivity.activities.isEmpty)
        UIApplication.shared.applicationState = .active
        ActivityAuthorizationInfo.enabled = false
        service.synchronize(.init(active: entry, upcoming: nil)); await drain()
        precondition(FakeActivity.activities.isEmpty)
        print("PASS: reuse, break update, dismissal, account change, stop in background, denied authorization")
        ActivityAuthorizationInfo.enabled = true
        let scheduleService = FocusLiveActivityService()
        var future = entry
        future.id = "accountB:ritual:same-end"
        future.state.startedAt = start.addingTimeInterval(3600)
        future.state.endsAt = start.addingTimeInterval(10800)
        future.state.breakStartedAt = nil
        future.state.breakEndsAt = nil
        future.state.scheduled = true
        scheduleService.synchronize(.init(active: nil, upcoming: future)); await drain()
        var previous = FakeActivity.activities[0]
        // Move later and then earlier, leaving the ID and end time unchanged.
        for offset in [5400.0, 1800.0] {
            future.state.startedAt = start.addingTimeInterval(offset)
            let count = FakeActivity.starts
            scheduleService.synchronize(.init(active: nil, upcoming: future)); await drain()
            precondition(previous.activityState == .ended, "Old start must be cancelled")
            precondition(FakeActivity.activities.count == 1 && FakeActivity.starts == count + 1)
            let replacement = FakeActivity.activities[0]
            precondition(replacement !== previous)
            precondition(replacement.scheduledStart == future.state.startedAt)
            precondition(replacement.content.state.endsAt == future.state.endsAt)
            previous = replacement
        }
        // Cosmetic edits update the existing pending card, without rescheduling.
        future.state.title = "Renamed"
        let count = FakeActivity.starts
        scheduleService.synchronize(.init(active: nil, upcoming: future)); await drain()
        precondition(FakeActivity.activities[0] === previous && FakeActivity.starts == count)
        precondition(previous.content.state.title == "Renamed")
        // Cancel a stale start in background; request the replacement on return.
        UIApplication.shared.applicationState = .background
        future.state.startedAt = start.addingTimeInterval(2700)
        scheduleService.synchronize(.init(active: nil, upcoming: future)); await drain()
        precondition(previous.activityState == .ended && FakeActivity.activities.isEmpty)
        UIApplication.shared.applicationState = .active
        scheduleService.synchronize(.init(active: nil, upcoming: future)); await drain()
        precondition(FakeActivity.activities.count == 1)
        precondition(FakeActivity.activities[0].scheduledStart == future.state.startedAt)
        // Once visible, updating the session's timing must not recreate its card.
        let visible = FakeActivity.activities[0]
        visible.activityState = .active
        future.state.startedAt = start
        future.state.scheduled = false
        scheduleService.synchronize(.init(active: future, upcoming: nil)); await drain()
        precondition(FakeActivity.activities[0] === visible && visible.activityState == .active)
        print("PASS: reschedule earlier/later, unchanged end, no duplicates, cosmetic edit, background deferral, active-card reuse")
        // Drive the production readiness policy as the root's task identity.
        FakeActivity.activities = []
        let restoreService = FocusLiveActivityService()
        var lastReadiness: FocusLiveActivitySyncState?
        func render(restoring: Bool, account: String?, restored: String?, legal: Bool,
                    canEnter: Bool = true, input: FocusLiveActivityInput) async {
            let readiness = FocusLiveActivitySyncState.resolve(isRestoring: restoring,
                authenticatedAccountID: account, restoredAccountID: restored,
                hasCheckedLegal: legal, canEnter: canEnter, input: input)
            guard lastReadiness != readiness else { return }
            lastReadiness = readiness
            switch readiness {
            case .waiting(let id): restoreService.waitForSession(retainingAccountID: id)
            case .signedOut: restoreService.synchronize(.init(active: nil, upcoming: nil))
            case .ready(let value): restoreService.synchronize(value)
            }
            await drain()
        }
        entry.id = "restored:occurrence"
        let restoredInput = FocusLiveActivityInput(active: entry, upcoming: nil)
        let beforeRestore = FakeActivity.starts
        await render(restoring: true, account: nil, restored: nil, legal: false, input: restoredInput)
        await render(restoring: false, account: "restored", restored: nil, legal: false, input: restoredInput)
        await render(restoring: false, account: "restored", restored: "restored", legal: false, input: restoredInput)
        precondition(FakeActivity.activities.isEmpty)
        // Only legal readiness changes; the ritual input stays identical.
        await render(restoring: false, account: "restored", restored: "restored", legal: true, input: restoredInput)
        precondition(FakeActivity.starts == beforeRestore + 1 && FakeActivity.activities.count == 1)
        let restoredCard = FakeActivity.activities[0]
        await render(restoring: false, account: "restored", restored: "restored", legal: false, input: restoredInput)
        precondition(FakeActivity.activities[0] === restoredCard)
        await render(restoring: false, account: "restored", restored: "restored", legal: true, input: restoredInput)
        precondition(FakeActivity.starts == beforeRestore + 1 && FakeActivity.activities[0] === restoredCard)
        // A confirmed account switch cleans old cards before the new legal load finishes.
        await render(restoring: false, account: "other", restored: "restored", legal: false, input: restoredInput)
        precondition(FakeActivity.activities.isEmpty)
        var other = entry; other.id = "other:occurrence"
        let otherInput = FocusLiveActivityInput(active: other, upcoming: nil)
        await render(restoring: false, account: "other", restored: "other", legal: true, input: otherInput)
        precondition(FakeActivity.activities.count == 1)
        // An unresolved restoration must retain an existing card; confirmed logout ends it.
        await render(restoring: true, account: nil, restored: nil, legal: false, input: otherInput)
        precondition(FakeActivity.activities.count == 1)
        await render(restoring: false, account: nil, restored: nil, legal: false, input: otherInput)
        precondition(FakeActivity.activities.isEmpty)
        print("PASS: initial restoration, delayed legal readiness, unchanged ritual input, card retention, no duplicates, account mismatch and confirmed logout")


    }
}
'''
with tempfile.TemporaryDirectory(prefix='rituo-live-lifecycle-') as directory:
    d = Path(directory); (d/'Tests.swift').write_text(source)
    subprocess.run(['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc', '-sdk', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk', '-parse-as-library', '-module-cache-path', str(d/'cache'), str(d/'Tests.swift'), '-o', str(d/'tests')], check=True)
    subprocess.run([str(d/'tests')], check=True)
