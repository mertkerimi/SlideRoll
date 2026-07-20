import Foundation
import Network
import Observation

// Lets views know instantly whether the device has any network path, so
// iCloud fetches (full-res photo, Live Photo, video) can fail fast with a
// clear "no connection" state instead of waiting out a request timeout.
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mertkerimi.slideroll.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}
