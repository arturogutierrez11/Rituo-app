#!/usr/bin/env python3
"""Execute the production calendar planner; no services or installed app data."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
source = (root / 'HolaSwift/Services/LiveActivitySchedulePlanner.swift').read_text() + r'''
@main struct Tests {
    static func main() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
        }
        let overnight = LiveActivitySchedulePlanner.next(weekdays: [7], startHour: 23, startMinute: 0,
            endHour: 2, endMinute: 0, now: date(2026, 10, 23, 12), calendar: cal)!
        precondition(overnight.start == date(2026, 10, 24, 23))
        precondition(overnight.end == date(2026, 10, 25, 2))
        let spring = LiveActivitySchedulePlanner.next(weekdays: [1], startHour: 1, startMinute: 0,
            endHour: 4, endMinute: 0, now: date(2026, 3, 7, 12), calendar: cal)!
        precondition(spring.start == date(2026, 3, 8, 1) && spring.end == date(2026, 3, 8, 4))
        precondition(spring.duration == 7200)
        let fall = LiveActivitySchedulePlanner.next(weekdays: [1], startHour: 1, startMinute: 0,
            endHour: 4, endMinute: 0, now: date(2026, 10, 31, 12), calendar: cal)!
        precondition(fall.end == date(2026, 11, 1, 4) && fall.duration == 14400)
        let followingWeek = LiveActivitySchedulePlanner.next(weekdays: [7], startHour: 23, startMinute: 0,
            endHour: 2, endMinute: 0, now: date(2026, 10, 25, 3), calendar: cal)!
        precondition(followingWeek.start == date(2026, 10, 31, 23))
        precondition(LiveActivitySchedulePlanner.next(weekdays: [], startHour: 1, startMinute: 0,
            endHour: 2, endMinute: 0, now: .now, calendar: cal) == nil)
        precondition(LiveActivitySchedulePlanner.next(weekdays: [1], startHour: 1, startMinute: 0,
            endHour: 1, endMinute: 0, now: .now, calendar: cal) == nil)
        print("PASS: next occurrence, midnight, week rollover, both DST transitions, empty and zero-length schedules")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='rituo-live-tests-') as directory:
    d = Path(directory)
    (d / 'Tests.swift').write_text(source)
    subprocess.run(['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc', '-sdk', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk', '-parse-as-library', '-module-cache-path', str(d / 'cache'), str(d / 'Tests.swift'), '-o', str(d / 'tests')], check=True)
    subprocess.run([str(d / 'tests')], check=True)
