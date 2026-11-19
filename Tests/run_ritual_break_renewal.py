#!/usr/bin/env python3
"""Exercise the real same-ritual fast path and persisted break restoration.

FamilyControls is replaced with scalar schedule fields; the schedule's actual
isActive/occurrenceStart methods run with a deterministic clock. No production
UserDefaults suite or services are touched.
"""
from pathlib import Path
import subprocess
import tempfile
import re
import os

root = Path(__file__).resolve().parents[1]
vm = (root / 'HolaSwift/Models/ViewModels/BlockSetupViewModel.swift').read_text()
scheduler = (root / 'HolaSwift/Models/RitualScheduler.swift').read_text()

def block(text, start):
    brace = text.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]

def method(text, name):
    match = re.search(r'^    (?:private )?func ' + name + r'\(', text, re.M)
    assert match, name
    return block(text, match.start()).replace('private func', 'func')

refresh = method(vm, 'refreshScheduledRitualState')
start = refresh.index('            if isBlocking,\n')
fast_path = block(refresh, start)
# Substitute only the clock used by the production calendar methods.
schedule_methods = '\n'.join(method(scheduler, name) for name in ['isActive', 'occurrenceStart', 'endDate'])
schedule_methods = schedule_methods.replace('Date = .now', 'Date = testNow')
restore_methods = '\n'.join(method(vm, name) for name in ['restoreRitualBreakUsage', 'resetRitualBreakUsage'])
restore_methods = restore_methods.replace('Date().addingTimeInterval', 'testNow.addingTimeInterval')
source = r'''
import Foundation
var testNow = Date()
struct RitualScheduler {
    let id: UUID
    let title = "Test ritual"
    let startHour: Int
    let startMinute = 0
    let endHour: Int
    let endMinute = 0
    let weekdays = Array(1...7)
    var crossesMidnight: Bool { endHour < startHour }
''' + schedule_methods + r'''
}
struct DebugStore { func log(_ text: String) {} }
final class Model {
    enum Source { case scheduled(UUID) }
    var isBlocking = true
    var activeBlockSource: Source
    var blockedUntil: Date?
    var ritualBreakUsedCount = 0
    var updates = 0
    let defaults: UserDefaults
    let deviceActivityDebugStore = DebugStore()
    let ritualBreakUsedSchedulerIDKey = "rituo.ritualBreakUsedSchedulerID"
    let ritualBreakUsedCountKey = "rituo.ritualBreakUsedCount"
    let ritualBreakUsedAtKey = "rituo.ritualBreakUsedAt"
    init(_ scheduler: RitualScheduler, defaults: UserDefaults) {
        activeBlockSource = .scheduled(scheduler.id)
        blockedUntil = testNow.addingTimeInterval(3600)
        self.defaults = defaults
    }
    func updateRemainingTime() { updates += 1 }
    // Exact production branch that returns before re-activating a known ritual.
    func refreshExistingOccurrence(_ scheduler: RitualScheduler) {
''' + fast_path + '\n    }\n' + restore_methods + r'''
}
@main struct Tests {
    static func main() {
        let suite = "rituo.break.renewal.test." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
        }
        func seed(_ model: Model, ritual: RitualScheduler, usedAt: Date?, count: Int) {
            defaults.set(ritual.id.uuidString, forKey: model.ritualBreakUsedSchedulerIDKey)
            defaults.set(count, forKey: model.ritualBreakUsedCountKey)
            if let usedAt { defaults.set(usedAt, forKey: model.ritualBreakUsedAtKey) }
            else { defaults.removeObject(forKey: model.ritualBreakUsedAtKey) }
            model.ritualBreakUsedCount = count
        }
        let daily = RitualScheduler(id: UUID(), startHour: 10, endHour: 12)
        testNow = at(16, 11)
        let model = Model(daily, defaults: defaults)
        seed(model, ritual: daily, usedAt: testNow, count: 2)
        model.refreshExistingOccurrence(daily)
        precondition(model.ritualBreakUsedCount == 2, "Do not renew the same occurrence")
        // Same model and ritual ID after suspension until the following day.
        testNow = at(17, 11)
        model.refreshExistingOccurrence(daily)
        precondition(model.ritualBreakUsedCount == 0, "Yesterday's exhausted allowance must renew")
        precondition(defaults.object(forKey: model.ritualBreakUsedCountKey) == nil)
        precondition(defaults.object(forKey: model.ritualBreakUsedAtKey) == nil)
        seed(model, ritual: daily, usedAt: testNow, count: 1)
        model.refreshExistingOccurrence(daily)
        model.refreshExistingOccurrence(daily)
        precondition(model.ritualBreakUsedCount == 1, "Refreshing must not grant extra breaks")
        let reopened = Model(daily, defaults: defaults)
        reopened.restoreRitualBreakUsage(for: daily)
        precondition(reopened.ritualBreakUsedCount == 1, "Reopening retains this occurrence's usage")
        testNow = at(18, 11)
        reopened.restoreRitualBreakUsage(for: daily)
        precondition(reopened.ritualBreakUsedCount == 0, "Cold restoration renews yesterday's usage")
        // Midnight belongs to the same overnight occurrence, not a new allowance.
        let overnight = RitualScheduler(id: UUID(), startHour: 23, endHour: 2)
        testNow = at(18, 23, 30)
        let night = Model(overnight, defaults: defaults)
        seed(night, ritual: overnight, usedAt: testNow, count: 2)
        testNow = at(19, 0, 30)
        night.refreshExistingOccurrence(overnight)
        precondition(night.ritualBreakUsedCount == 2, "Midnight must not renew an ongoing ritual")
        precondition(overnight.occurrenceStart() == at(18, 23))
        testNow = at(19, 23, 30)
        night.refreshExistingOccurrence(overnight)
        precondition(night.ritualBreakUsedCount == 0, "The next overnight occurrence renews")
        // Legacy records lack the date added by the renewal fix.
        seed(night, ritual: overnight, usedAt: nil, count: 3)
        night.refreshExistingOccurrence(overnight)
        precondition(night.ritualBreakUsedCount == 0)
        print("PASS: same-ID next day, persisted reset, same-occurrence refresh, cold restoration, midnight, next overnight occurrence, legacy record")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='rituo-break-renewal-') as directory:
    d = Path(directory); (d/'Tests.swift').write_text(source)
    subprocess.run(['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc', '-sdk', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk', '-parse-as-library', '-module-cache-path', str(d/'cache'), str(d/'Tests.swift'), '-o', str(d/'tests')], check=True)
    subprocess.run([str(d/'tests')], env={**os.environ, 'TZ': 'America/Argentina/Buenos_Aires'}, check=True)
