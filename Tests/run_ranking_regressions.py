#!/usr/bin/env python3
"""Run the production RankingViewModel against controllable network responses.

Compiles the real model and response types; the API adapter deliberately permits
late responses after cancellation. Does not emulate SwiftUI scene transitions.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
page = (root / 'HolaSwift/Views/Ranking/RankingPage.swift').read_text()
model = page.split('// MARK: - Page')[0].replace('import SwiftUI', 'import Foundation')
responses = (root / 'HolaSwift/Models/RankingModels.swift').read_text()
adapter = r'''
enum CoreAPIError: Error { case cancelled }
enum NetworkFailure: Error { case offline }
@MainActor final class AppDiagnostics {
    static let shared = AppDiagnostics()
    func event(_ message: String) {}
}
@MainActor final class CoreApiService {
    static let shared = CoreApiService()
    var requests: [CheckedContinuation<RankingResponse, Error>?] = []
    func getRanking(accessToken: String) async throws -> RankingResponse {
        try await withCheckedThrowingContinuation { requests.append($0) }
    }
    func succeed(_ index: Int, _ response: RankingResponse) {
        let continuation = requests[index]!
        requests[index] = nil
        continuation.resume(returning: response)
    }
    func fail(_ index: Int, _ error: Error) {
        let continuation = requests[index]!
        requests[index] = nil
        continuation.resume(throwing: error)
    }
}
'''
tests = r'''
@main struct RegressionTests {
    @MainActor static func main() async {
        let api = CoreApiService.shared
        func response(_ count: Int) -> RankingResponse {
            RankingResponse(period: "month", periodStart: "2026-11-01T00:00:00Z",
                periodEnd: "2026-12-01T00:00:00Z", timeZone: "UTC",
                totalUsers: count, participants: 0,
                me: RankingMe(position: nil, displayName: nil,
                    totalFocusSeconds: 0, totalFocusMinutes: 0), entries: [])
        }
        func start(_ model: RankingViewModel) async -> (Int, Task<Void, Never>) {
            let index = api.requests.count
            let task = Task { await model.load(accessToken: "same-session") }
            while api.requests.count <= index { await Task.yield() }
            return (index, task)
        }

        let model = RankingViewModel()
        let (oldIndex, old) = await start(model)
        let (newIndex, new) = await start(model)
        api.succeed(newIndex, response(200)); await new.value
        api.succeed(oldIndex, response(100)); await old.value
        precondition(model.ranking?.totalUsers == 200 && !model.isRefreshing)
        print("PASS: older success cannot overwrite the newest response")

        let (failureIndex, failure) = await start(model)
        let (freshIndex, fresh) = await start(model)
        api.succeed(freshIndex, response(300)); await fresh.value
        api.fail(failureIndex, NetworkFailure.offline); await failure.value
        precondition(model.ranking?.totalUsers == 300 && model.refreshError == nil)
        print("PASS: older failure cannot add an error to a newer successful refresh")

        let initial = RankingViewModel()
        let (cancelIndex, cancelled) = await start(initial)
        let (pendingIndex, pending) = await start(initial)
        cancelled.cancel()
        api.fail(cancelIndex, CancellationError()); await cancelled.value
        guard case .loading = initial.state else { fatalError("Old cancellation reset the new load") }
        precondition(initial.isRefreshing && initial.refreshError == nil)
        api.succeed(pendingIndex, response(400)); await pending.value
        print("PASS: older cancellation leaves the newest loading state intact")

        let (offlineIndex, offline) = await start(model)
        precondition(model.ranking?.totalUsers == 300 && model.isRefreshing)
        api.fail(offlineIndex, NetworkFailure.offline); await offline.value
        precondition(model.ranking?.totalUsers == 300 && model.refreshError != nil && !model.isRefreshing)
        let (retryIndex, retry) = await start(model)
        precondition(model.refreshError == nil && model.isRefreshing && model.ranking?.totalUsers == 300)
        api.succeed(retryIndex, response(500)); await retry.value
        precondition(model.ranking?.totalUsers == 500 && model.refreshError == nil && !model.isRefreshing)
        print("PASS: failed refresh retains data, exposes retry, and clears the notice on recovery")

        let empty = RankingViewModel()
        let (emptyIndex, emptyLoad) = await start(empty)
        api.fail(emptyIndex, NetworkFailure.offline); await emptyLoad.value
        guard case .failed = empty.state else { fatalError("Initial failure must show the full error state") }
        precondition(empty.ranking == nil && empty.refreshError == nil && !empty.isRefreshing)
        let (emptyRetryIndex, emptyRetry) = await start(empty)
        api.fail(emptyRetryIndex, CoreAPIError.cancelled); await emptyRetry.value
        guard case .idle = empty.state else { fatalError("Initial cancellation should permit another load") }
        precondition(empty.refreshError == nil && !empty.isRefreshing)
        print("PASS: initial failures and cancellation remain distinct from refresh errors")

        for returnSuccess in [true, false] {
            let (index, task) = await start(model)
            task.cancel()
            if returnSuccess { api.succeed(index, response(999)) }
            else { api.fail(index, NetworkFailure.offline) }
            await task.value
            precondition(model.ranking?.totalUsers == 500 && model.refreshError == nil && !model.isRefreshing)
        }
        print("PASS: cancelled requests cannot publish late success or network errors")

        let (staleIndex, stale) = await start(model)
        let (latestIndex, latest) = await start(model)
        api.fail(latestIndex, NetworkFailure.offline); await latest.value
        api.succeed(staleIndex, response(777)); await stale.value
        precondition(model.ranking?.totalUsers == 500 && model.refreshError != nil && !model.isRefreshing)
        precondition(api.requests.allSatisfy { $0 == nil })
        print("PASS: stale success cannot erase the latest refresh error")
    }
}
'''

with tempfile.TemporaryDirectory(prefix='rituo-ranking-tests-') as directory:
    path = Path(directory)
    source = path / 'Tests.swift'
    source.write_text(responses + model + adapter + tests)
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(source),
                    '-o', str(path / 'tests')], check=True)
    subprocess.run([str(path / 'tests')], check=True)
