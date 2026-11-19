import Foundation

/// Serializes secondary monitor registration and cancellation off the UI thread.
/// A queued cancellation always runs after an earlier registration, including logout.
nonisolated final class DeviceActivityCommandQueue: @unchecked Sendable {
    static let shared = DeviceActivityCommandQueue()
    private let queue = DispatchQueue(label: "io.rituo.device-activity.commands", qos: .userInitiated)

    func submit(_ operation: @escaping @Sendable () -> Void) {
        queue.async(execute: operation)
    }
}

/// Keeps metadata preparation on MainActor while preserving command order across awaits.
@MainActor
final class DeviceActivityOperationQueue {
    private var pending: Task<Void, Never>?

    func submit(_ operation: @escaping @MainActor () async -> Void) {
        let previous = pending
        pending = Task {
            await previous?.value
            await operation()
        }
    }
}
