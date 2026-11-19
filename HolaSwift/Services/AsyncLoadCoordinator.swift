import Foundation

/// Shares concurrent loads with the same scope. Keys remain in memory and are never logged.
@MainActor
final class AsyncLoadCoordinator {
    private var tasks: [String: Task<Void, Never>] = [:]

    func run(key: String, operation: @escaping @MainActor () async -> Void) async {
        if let task = tasks[key] {
            await task.value
            return
        }
        // The shared load outlives a disappearing tab; every caller awaits the same result.
        let task = Task { await operation() }
        tasks[key] = task
        await task.value
        tasks[key] = nil
    }
}
