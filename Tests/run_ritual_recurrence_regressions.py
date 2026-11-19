#!/usr/bin/env python3
"""Verify a suppressed occurrence keeps its future DeviceActivity registrations."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
view_model = (root / 'HolaSwift/Models/ViewModels/BlockSetupViewModel.swift').read_text()
start = view_model.index('    private func rescheduleDeviceActivities()')
end = view_model.index('\n    }', start) + 6
method = view_model[start:end].replace('private func', 'func')
store = (root / 'HolaSwift/Services/SharedRitualSuppressionStore.swift').read_text()
# Isolate the production store from all installed app data.
store = store.replace('"group.io.rituo.app"', 'testSuite')
source = '''
import Foundation
let testSuite = "rituo.recurrence.test." + UUID().uuidString
struct RitualScheduler { let id: UUID }
struct DebugStore { func log(_ value: String) {} }
@MainActor final class Monitor {
    var registered: [UUID] = []
    func reschedule(_ values: [RitualScheduler], userID: String?, completion: @escaping @MainActor (Error?) -> Void) {
        registered = values.map(\\.id)
        completion(nil)
    }
}
struct Notifications { func rescheduleNotifications(for values: [RitualScheduler]) {} }
@MainActor final class Model {
    let activeAccountID: String? = "test"
    var schedulers: [RitualScheduler] = []
    var suppressed: Set<UUID> = []
    let deviceActivityScheduler = Monitor()
    let notificationService = Notifications()
    let deviceActivityDebugStore = DebugStore()
    var schedulerMessage: String?
    func isSchedulerSuppressed(_ value: RitualScheduler) -> Bool { suppressed.contains(value.id) }
    func refreshDeviceActivityDebugEvents() {}
''' + method + '\n}\n' + store + '''
@main struct Tests {
    @MainActor static func main() {
        defer { UserDefaults(suiteName: testSuite)?.removePersistentDomain(forName: testSuite) }
        let ritual = RitualScheduler(id: UUID())
        let model = Model()
        model.schedulers = [ritual]
        model.suppressed = [ritual.id]
        model.rescheduleDeviceActivities()
        precondition(model.deviceActivityScheduler.registered == [ritual.id], "Suppression removed future monitors")
        let other = RitualScheduler(id: UUID())
        model.schedulers = [ritual, other]
        model.rescheduleDeviceActivities()
        precondition(model.deviceActivityScheduler.registered == [ritual.id, other.id], "NFC must retain both overlapping rituals")
        let store = SharedRitualSuppressionStore()
        let end = Date(timeIntervalSince1970: 2_000_000_000)
        store.replaceSuppressions([ritual.id: end])
        precondition(store.isSuppressed(schedulerId: ritual.id.uuidString, at: end.addingTimeInterval(-1)))
        precondition(!store.isSuppressed(schedulerId: ritual.id.uuidString, at: end))
        precondition(!store.isSuppressed(schedulerId: ritual.id.uuidString, at: end.addingTimeInterval(86400)))
        print("PASS: suppressed ritual and overlapping ritual stay registered; suppression expires without reopening the app")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='rituo-recurrence-tests-') as directory:
    d = Path(directory)
    (d / 'Tests.swift').write_text(source)
    subprocess.run(['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc', '-sdk', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk', '-parse-as-library', '-module-cache-path', str(d / 'cache'), str(d / 'Tests.swift'), '-o', str(d / 'tests')], check=True)
    subprocess.run([str(d / 'tests')], check=True)
