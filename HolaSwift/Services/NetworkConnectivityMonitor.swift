import Foundation
import Network

final class NetworkConnectivityMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(
        label: "io.rituo.network-connectivity",
        qos: .utility
    )
    private var didObserveDisconnectedPath = false
    private var isStarted = false

    func start(onConnectivityRestored: @escaping @Sendable () -> Void) {
        guard !isStarted else { return }
        isStarted = true

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            if path.status == .satisfied {
                if didObserveDisconnectedPath {
                    didObserveDisconnectedPath = false
                    onConnectivityRestored()
                }
            } else {
                didObserveDisconnectedPath = true
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        monitor.cancel()
    }

    deinit {
        monitor.cancel()
    }
}
