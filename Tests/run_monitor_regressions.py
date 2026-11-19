#!/usr/bin/env python3
"""Exercise production callback/heartbeat methods with a deterministic DeviceActivity fake."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
monitor = (root/'RituoDeviceActivityMonitor/RituoDeviceActivityMonitor.swift').read_text()
def method(name):
    start = monitor.index('    private func '+name+'(')
    end = monitor.index('\n    }', start) + 6
    return monitor[start:end].replace('private func', 'func')
source = r'''
import Foundation
struct DeviceActivityName: Hashable { let rawValue: String; init(_ value: String) { rawValue = value } }
struct DeviceActivitySchedule { let intervalStart: DateComponents; let intervalEnd: DateComponents; let repeats: Bool }
final class Center {
    var activities: [DeviceActivityName] = []
    var starts = 0
    var stops = 0
    var onStop: (() -> Void)?
    func startMonitoring(_ name: DeviceActivityName, during: DeviceActivitySchedule) throws { starts += 1; activities.append(name) }
    func stopMonitoring(_ names: [DeviceActivityName]) { stops += 1; activities.removeAll { names.contains($0) }; onStop?() }
}
final class MetadataStore {
    var names: Set<String> = []
    func loadMetadata(for name: String) -> String? { names.contains(name) ? name : nil }
    func removeMetadata(for name: String) { names.remove(name) }
}
struct SelectionStore { func removeSelection(for name: String) {} }
struct DebugStore { func log(_ message: String) {} }
final class SuppressionStore {
    var name: String?
    var expiration: Date?
    func heartbeatActivityName() -> String? { name }
    func heartbeatExpiration() -> Date? { expiration }
    func setHeartbeatActivityName(_ value: String?) { name = value; if value == nil { expiration = nil } }
    func setHeartbeatExpiration(_ value: Date) { expiration = value }
    func takeModeBreakActivityName() -> String? { nil }
    func takeRitualBreakActivityName() -> String? { nil }
}
final class Monitor {
    static let breakCompletionLock = NSRecursiveLock()
    static let heartbeatActivityPrefix = "heartbeat."
    static let heartbeatInterval: TimeInterval = 7200
    let center = Center()
    let metadataStore = MetadataStore()
    let selectionStore = SelectionStore()
    let suppressionStore = SuppressionStore()
    let debugStore = DebugStore()
    var notifications = 0
    var reconciliations = 0
    func restoreModeShieldAfterBreak(_ activity: DeviceActivityName) { reconciliations += 1 }
    func sendModeBreakEndedNotification(_ activity: DeviceActivityName) { notifications += 1 }
    func sendRitualBreakEndedNotification(_ activity: DeviceActivityName) { notifications += 1 }
    func reconcileActiveRitualShield() { reconciliations += 1 }
''' + '\n'.join(method(n) for n in ['finishModeBreakActivity','finishRitualBreakActivity','maintainHeartbeat','cancelHeartbeat']) + r'''
}
@main struct Tests {
    static func main() {
        for mode in [false, true] {
            let m = Monitor(); let name = DeviceActivityName("break")
            m.metadataStore.names.insert(name.rawValue)
            let finish = { if mode { m.finishModeBreakActivity(name, source: "end") } else { m.finishRitualBreakActivity(name, source: "end") } }
            // stopMonitoring can trigger a callback before the original handler returns.
            m.center.onStop = finish
            finish(); finish()
            precondition(m.notifications == 1 && m.reconciliations == 1 && m.center.stops == 1)
        }
        let m = Monitor()
        m.maintainHeartbeat(isActive: true)
        let first = m.suppressionStore.name
        m.maintainHeartbeat(isActive: true)
        precondition(m.center.starts == 1 && m.suppressionStore.name == first)
        m.suppressionStore.expiration = .distantPast
        m.maintainHeartbeat(isActive: true)
        precondition(m.center.starts == 2 && m.center.stops == 1 && m.suppressionStore.name != first)
        m.maintainHeartbeat(isActive: false)
        precondition(m.suppressionStore.name == nil && m.center.activities.isEmpty)
        print("PASS: duplicate/reentrant mode and ritual callbacks, heartbeat reuse, expired heartbeat replacement, cancellation")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='rituo-monitor-tests-') as directory:
    d=Path(directory); (d/'Tests.swift').write_text(source)
    subprocess.run(['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc',
        '-sdk','/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk',
        '-parse-as-library','-module-cache-path',str(d/'cache'),str(d/'Tests.swift'),'-o',str(d/'tests')],check=True)
    subprocess.run([str(d/'tests')],check=True)
