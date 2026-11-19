#!/usr/bin/env python3
"""Test the production refresh coordinator and serial monitor executor without network/device access."""
from pathlib import Path
import tempfile, subprocess
root=Path(__file__).resolve().parents[1]
source=r'''
import Foundation
struct TokenResponse { let accessToken: String; let refreshToken: String }
@MainActor final class KeychainTokenStore {
    static let shared = KeychainTokenStore()
    var sessionRevision = UUID()
    func loadAccessToken() -> String? { nil }
    func loadRefreshToken() -> String? { nil }
    func save(accessToken: String, refreshToken: String) throws {}
}
@MainActor final class AuthAPIClient {
    static let shared = AuthAPIClient()
    func refreshTokens(refreshToken: String) async throws -> TokenResponse { fatalError("Live network is forbidden") }
}
@MainActor final class Store {
    var snapshot: SessionTokenCoordinator.Snapshot? = .init(revision: UUID(), accessToken: "old", refreshToken: "refresh")
    var calls = 0
    var saves = 0
    var continuation: CheckedContinuation<TokenResponse, Error>?
    lazy var coordinator = SessionTokenCoordinator(load: { self.snapshot }, save: { tokens in
        self.saves += 1
        self.snapshot = .init(revision: self.snapshot!.revision, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
    }, renew: { _ in
        self.calls += 1
        return try await withCheckedThrowingContinuation { self.continuation = $0 }
    })
}
final class Sequence: @unchecked Sendable { var values: [String] = [] }
@main struct Tests {
    @MainActor static func main() async throws {
        let store=Store()
        let tasks = (0..<10).map { _ in Task { try await store.coordinator.refresh(accessToken: "old") } }
        while store.continuation == nil { await Task.yield() }
        // Let all ten callers join the same suspended renewal.
        for _ in 0..<30 { await Task.yield() }
        precondition(store.calls == 1)
        store.continuation!.resume(returning: .init(accessToken: "new", refreshToken: "rotated")); store.continuation=nil
        for task in tasks { let token=try await task.value; precondition(token.accessToken == "new") }
        precondition(store.saves == 1)
        let late=try await store.coordinator.refresh(accessToken: "old")
        precondition(late.accessToken == "new" && store.calls == 1, "Late 401 reuses rotated token")
        let pending=Task { try await store.coordinator.refresh(accessToken: "new") }
        while store.continuation == nil { await Task.yield() }
        let other=SessionTokenCoordinator.Snapshot(revision: UUID(), accessToken: "other", refreshToken: "other-refresh")
        store.snapshot=other
        store.continuation!.resume(returning: .init(accessToken: "stale", refreshToken: "stale-refresh")); store.continuation=nil
        do { _ = try await pending.value; fatalError("Stale response accepted") } catch is CancellationError {}
        precondition(store.snapshot == other && store.saves == 1)
        do { _ = try store.coordinator.accessToken(for: "old"); fatalError("Old account accepted") } catch is CancellationError {}
        store.snapshot=nil
        do { _ = try store.coordinator.accessToken(for: "other"); fatalError("Logout ignored") } catch is CancellationError {}
        let sequence=Sequence()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            let queue=DeviceActivityCommandQueue()
            queue.submit { precondition(!Thread.isMainThread); sequence.values.append("register") }
            queue.submit { precondition(!Thread.isMainThread); sequence.values.append("cancel") }
            queue.submit { precondition(sequence.values == ["register", "cancel"]); done.resume() }
        }
        print("PASS: ten concurrent refreshes, rotated token reuse, account change/logout isolation, monitor FIFO off main thread")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='rituo-session-tests-') as directory:
 d=Path(directory);(d/'Tests.swift').write_text(source)
 subprocess.run(['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc',
 '-sdk','/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk',
 '-parse-as-library','-module-cache-path',str(d/'cache'),str(root/'HolaSwift/Services/SessionTokenCoordinator.swift'),
 str(root/'HolaSwift/Services/DeviceActivityCommandQueue.swift'),str(d/'Tests.swift'),'-o',str(d/'tests')],check=True)
 subprocess.run([str(d/'tests')],check=True)
