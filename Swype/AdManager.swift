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

    override init() {
        super.init()
        Task { await load() }
    }

    func load() async {
        do {
            interstitial = try await InterstitialAd.load(
                with: adUnitID,
                request: Request()
            )
            interstitial?.fullScreenContentDelegate = self
            isReady = true
        } catch {
            isReady = false
        }
    }

    func showIfReady(from vc: UIViewController? = nil) {
        guard isReady, let ad = interstitial else { return }
        let root = vc ?? topViewController()
        guard let root else { return }
        ad.present(from: root)
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
