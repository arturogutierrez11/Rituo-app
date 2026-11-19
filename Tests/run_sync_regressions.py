#!/usr/bin/env python3
"""Run production outbox/coordinator/break-sync code with an in-memory store and fake API.
Requires Xcode's macOS Swift SDK; does not contact Rituo services.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
vm = (root / 'HolaSwift/Models/ViewModels/BlockSetupViewModel.swift').read_text()
def block(marker):
    start = vm.index(marker)
    end = vm.index('\n    }', start) + 6
    return vm[start:end].replace('private ', '')
methods = '\n'.join(block('    private '+signature) for signature in [
    'struct PendingModeBreakConfig:', 'struct PendingRitualBreakConfig:',
    'func loadModeBreakConfigs(', 'func loadRitualBreakConfigs(',
    'func syncModeBreakConfig(', 'func syncRitualBreakConfig(',
    'func syncPendingModeBreakConfigs(', 'func syncPendingRitualBreakConfigs(',
    'func drainModeBreakConfigs(', 'func drainRitualBreakConfigs(',
    'static func isPermanentBreakConfigError(', 'static func scopedSyncOperationID('
])
source = r'''
import Foundation
import SwiftData
import CryptoKit
struct SaveBreakConfigRequest: Codable { let breakCount: Int; let breakDurationMinutes: Int }
enum CoreAPIError: Error { case serverError(Int, String, String?); case timedOut }
struct Item<ID: Equatable> {
    let id: ID
    var coreModeId: String? = "remote"
    var coreRitualId: String? = "remote"
    var breakCount = 3
    var breakDurationMinutes = 5
    func breakConfigRequest() -> SaveBreakConfigRequest {
        .init(breakCount: breakCount, breakDurationMinutes: breakDurationMinutes)
    }
    func withBreakConfig(breakCount: Int, breakDurationMinutes: Int) -> Self {
        var copy = self; copy.breakCount = breakCount; copy.breakDurationMinutes = breakDurationMinutes; return copy
    }
}
@MainActor final class FakeAPI {
    var requests: [SaveBreakConfigRequest] = []
    var failure: CoreAPIError? = .timedOut
    var paused = false
    var continuation: CheckedContinuation<Void, Never>?
    var reads = 0
    func send(_ request: SaveBreakConfigRequest) async throws -> Bool {
        requests.append(request)
        if paused { await withCheckedContinuation { continuation = $0 } }
        if let failure { throw failure }; return true
    }
    func saveModeBreakConfig(accessToken: String, modeId: String, body: SaveBreakConfigRequest) async throws -> Bool { try await send(body) }
    func saveRitualBreakConfig(accessToken: String, ritualId: String, body: SaveBreakConfigRequest) async throws -> Bool { try await send(body) }
    func getModeBreakConfig(accessToken: String, modeId: String) async throws -> SaveBreakConfigRequest { reads += 1; return .init(breakCount: 0, breakDurationMinutes: 1) }
    func getRitualBreakConfig(accessToken: String, ritualId: String) async throws -> SaveBreakConfigRequest { reads += 1; return .init(breakCount: 0, breakDurationMinutes: 1) }
}
struct FakeModeStore { func save(_ modes: [Item<String>], accountID: String) {} }
struct AppDiagnostics {
    static let shared = Self()
    func begin(_ name: String) -> Int { 0 }
    func end(_ name: String, _ span: Int) {}
}
struct CrashReportingService { static func record(_ error: Error, context: [String: String]) {} }
@MainActor final class Harness {
    let syncOutbox: SyncOutboxStore
    let coreApi = FakeAPI()
    let breakCoordinator = AsyncLoadCoordinator()
    let modeStore = FakeModeStore()
    var activeAccountID: String? = "account"
    var activeAccessToken: String? = "token"
    var modes = [Item(id: "mode")]
    var schedulers = [Item(id: UUID())]
    var coreSyncMessage: String?
    init() throws {
        syncOutbox = SyncOutboxStore(container: try ModelContainer(for: PendingSyncOperation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }
    func refreshSyncOutboxStatus() {}
    func persistSchedulers() {}
    func scheduleConfigurationOutboxRetry(userID: String, accessToken: String) {}
''' + methods + r'''
}
@main struct RegressionTests {
    @MainActor static func main() async throws {
        let h = try Harness()
        await h.syncModeBreakConfig(coreModeID: "remote", localModeID: "mode", accessToken: "token")
        let op = h.syncOutbox.operations(userID: "account", type: .syncModeBreakConfig).first!
        precondition(op.attempts == 1 && op.nextRetryAt > Date())
        await h.syncPendingModeBreakConfigs(userID: "account", accessToken: "token")
        precondition(h.coreApi.requests.count == 1, "No immediate retry")
        await h.loadModeBreakConfigs(accessToken: "token")
        precondition(h.coreApi.reads == 0 && h.modes[0].breakCount == 3, "Pending local edits survive GET")
        h.modes[0].breakCount = 8
        op.nextRetryAt = .distantPast
        await h.syncPendingModeBreakConfigs(userID: "account", accessToken: "token")
        precondition(h.coreApi.requests.last!.breakCount == 3, "Retry keeps payload snapshot")
        precondition(op.attempts == 2 && op.nextRetryAt.timeIntervalSinceNow > 8)
        h.coreApi.failure = .serverError(400, "invalid", nil)
        op.nextRetryAt = .distantPast
        await h.syncPendingModeBreakConfigs(userID: "account", accessToken: "token")
        precondition(op.statusRawValue == SyncOperationStatus.failed.rawValue)
        precondition(h.syncOutbox.nextRetryDate(userID: "account", type: .syncModeBreakConfig) == nil)
        await h.loadModeBreakConfigs(accessToken: "token")
        precondition(h.coreApi.reads == 0, "Failed edit also survives GET")
        h.syncOutbox.retryFailed(userID: "account")
        h.coreApi.failure = nil
        h.coreApi.paused = true
        let task = Task { await h.syncPendingModeBreakConfigs(userID: "account", accessToken: "token") }
        while h.coreApi.continuation == nil { await Task.yield() }
        let newPayload = try JSONEncoder().encode(Harness.PendingModeBreakConfig(localModeID: "mode", coreModeID: "remote", request: .init(breakCount: 9, breakDurationMinutes: 5)))
        let id = op.id
        try h.syncOutbox.upsertScoped(id: id, userID: "account", type: .syncModeBreakConfig, payload: newPayload)
        h.coreApi.continuation!.resume(); h.coreApi.continuation = nil
        await task.value
        precondition(h.syncOutbox.contains(id: id), "Old success cannot remove newer revision")
        let task2 = Task { await h.syncPendingModeBreakConfigs(userID: "account", accessToken: "token") }
        while h.coreApi.continuation == nil { await Task.yield() }
        h.activeAccountID = "another-account"
        h.coreApi.continuation!.resume(); h.coreApi.continuation = nil
        await task2.value
        precondition(h.syncOutbox.contains(id: id), "Old account response cannot acknowledge queue")
        h.activeAccountID = "account"; h.coreApi.paused = false
        await h.syncPendingModeBreakConfigs(userID: "account", accessToken: "token")
        precondition(!h.syncOutbox.contains(id: id))
        let ritualID = h.schedulers[0].id
        h.coreApi.failure = .serverError(422, "invalid", nil)
        await h.syncRitualBreakConfig(coreRitualID: "remote", localSchedulerID: ritualID, accessToken: "token")
        let ritualOp = h.syncOutbox.operations(userID: "account", type: .syncRitualBreakConfig).first!
        precondition(ritualOp.statusRawValue == SyncOperationStatus.failed.rawValue)
        await h.loadRitualBreakConfigs(accessToken: "token")
        precondition(h.schedulers[0].breakCount == 3)
        let limited = try Harness()
        await limited.syncModeBreakConfig(coreModeID: "remote", localModeID: "mode", accessToken: "token")
        let limitedOp = limited.syncOutbox.operations(userID: "account", type: .syncModeBreakConfig).first!
        for _ in 1..<8 {
            limitedOp.nextRetryAt = .distantPast
            await limited.syncPendingModeBreakConfigs(userID: "account", accessToken: "token")
        }
        precondition(limitedOp.attempts == 8 && limitedOp.statusRawValue == SyncOperationStatus.failed.rawValue)
        await limited.syncPendingModeBreakConfigs(userID: "account", accessToken: "token")
        precondition(limited.coreApi.requests.count == 8, "No ninth automatic attempt")
        let legacy = Data("{\"localModeID\":\"mode\",\"coreModeID\":\"remote\"}".utf8)
        let decodedLegacy = try JSONDecoder().decode(Harness.PendingModeBreakConfig.self, from: legacy)
        precondition(decodedLegacy.request == nil)
        print("PASS: backoff, retry limit policy, immutable payload, pending/failed read protection, newer revision, account switch, ritual validation failure")
    }
}
'''
creation = (root/'Tests/creation_harness.swift').read_text()
creation_methods = '\n'.join(block('    private '+signature) for signature in [
    'struct PendingRitualConfiguration:', 'struct PendingRitualUpdate:',
    'func queueRitualConfiguration(', 'func queueRitualUpdate(',
    'func syncPendingRitualConfigurations(', 'func clearConfigurationOperation(',
    'static func scopedSyncOperationID('
])
creation = creation.replace('    // PRODUCTION_METHODS', creation_methods)
source = source.replace('@main struct RegressionTests', creation + '\n@main struct RegressionTests')
source = source.replace('        let h = try Harness()', '        try await runCreationTests()\n        let h = try Harness()', 1)

with tempfile.TemporaryDirectory(prefix='rituo-sync-tests-') as directory:
    d = Path(directory)
    (d / 'Harness.swift').write_text(source)
    command = ['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc',
               '-sdk', '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk', '-parse-as-library', '-module-cache-path', str(d/'cache'),
               str(root/'HolaSwift/Models/PendingSyncOperation.swift'),
               str(root/'HolaSwift/Services/SyncOutboxStore.swift'),
               str(root/'HolaSwift/Services/AsyncLoadCoordinator.swift'),str(d/'Harness.swift'),'-o',str(d/'tests')]
    subprocess.run(command, check=True)
    subprocess.run([str(d/'tests')], check=True)
