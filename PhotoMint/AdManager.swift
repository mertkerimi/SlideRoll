import GoogleMobileAds
import UIKit

@MainActor
@Observable
final class AdManager: NSObject {

    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910" // Google test ID
    #else
    private let adUnitID = "ca-app-pub-9987963380054913/4228054037"
    #endif

    private var interstitial: InterstitialAd?
    private(set) var isReady = false

    // MARK: - Frequency policy
    private let launchGrace: TimeInterval = 20     // no ads in the first 20s of a session
    private let cooldown: TimeInterval     = 60    // minimum seconds between interstitials
    private let appStart = Date()
    private var lastShownAt: Date?
    private var retryDelay: UInt64 = 2             // seconds, exponential backoff on load failure

    override init() {
        super.init()
        Task { await load() }
    }

    // MARK: - Load (with backoff retry so ads recover after a transient failure)
    func load() async {
        do {
            interstitial = try await InterstitialAd.load(with: adUnitID, request: Request())
            interstitial?.fullScreenContentDelegate = self
            isReady = true
            retryDelay = 2
        } catch {
            isReady = false
            try? await Task.sleep(nanoseconds: retryDelay * 1_000_000_000)
            retryDelay = min(retryDelay * 2, 64)
            await load()
        }
    }

    /// Presents an interstitial only when it's appropriate: an ad is loaded, the
    /// launch grace has passed, and the cooldown since the last ad has elapsed.
    /// Call this at natural break points; the policy keeps it non-intrusive.
    func maybeShow(from vc: UIViewController? = nil) {
        guard isReady else { return }
        let now = Date()
        guard now.timeIntervalSince(appStart) >= launchGrace else { return }
        if let last = lastShownAt, now.timeIntervalSince(last) < cooldown { return }
        present(from: vc)
    }

    private func present(from vc: UIViewController?) {
        guard let ad = interstitial, let root = vc ?? topViewController() else { return }
        ad.present(from: root)
        lastShownAt = Date()
        isReady = false
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow })
        else { return nil }

        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

extension AdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in await self.load() }
    }
}
