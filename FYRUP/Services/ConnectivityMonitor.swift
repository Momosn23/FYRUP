import Foundation
import Network
import OSLog

/// Process-wide reachability signal. It never treats reachability as proof that a
/// backend request will succeed; it is used only to classify failures and trigger
/// fresh reads when a route returns.
final class ConnectivityMonitor: @unchecked Sendable {
    static let shared = ConnectivityMonitor()
    static let didReconnect = Notification.Name("FYRUPConnectivityDidReconnect")

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.fyrup.connectivity")
    private let lock = NSLock()
    private var available: Bool?
    private var interfaces: [Bool] = []
    private let logger = Logger(subsystem: "app.fyrup.ios", category: "Connectivity")

    var isAvailable: Bool? { lock.withLock { available } }
    var logLabel: String {
        switch isAvailable {
        case true: "true"
        case false: "false"
        case nil: "unknown"
        }
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let next = path.status == .satisfied
            let signature = [path.usesInterfaceType(.wifi), path.usesInterfaceType(.cellular), path.usesInterfaceType(.wiredEthernet), path.usesInterfaceType(.other), path.usesInterfaceType(.loopback)]
            let previous = self.lock.withLock { () -> (Bool?, Bool) in
                let old = self.available
                let changed = self.interfaces != signature
                self.available = next
                self.interfaces = signature
                return (old, changed)
            }
            self.logger.info("Network path available=\(next, privacy: .public)")
            if Self.shouldReconnect(wasAvailable: previous.0, isAvailable: next, interfacesChanged: previous.1) {
                self.logger.info("Reconnect detected; scheduling core refresh")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.didReconnect, object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }

    static func shouldReconnect(wasAvailable: Bool?, isAvailable: Bool, interfacesChanged: Bool) -> Bool {
        isAvailable && wasAvailable != nil && (wasAvailable == false || interfacesChanged)
    }
}
