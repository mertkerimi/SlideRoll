import GoogleMobileAds
import UIKit

@MainActor
@Observable
final class AdManager: NSObject {

    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910" // Google test ID
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313" // Google test ID
    #else
    private let adUnitID = "ca-app-pub-9987963380054913/4228054037"
    private let rewardedAdUnitID = "ca-app-pub-9987963380054913/7615220968" // "Bonus Swipes Rewarded"
    #endif

    private var interstitial: InterstitialAd?
    private(set) var isReady = false

    private var rewardedAd: RewardedAd?
    private(set) var isRewardedReady = false
    private var rewardedRetryDelay: UInt64 = 2

    private var retryDelay: UInt64 = 2
    var isPremium = false

    override init() {
        super.init()
        Task { await load() }
        Task { await loadRewarded() }
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

    func show(from vc: UIViewController? = nil) {
        guard isReady, !isPremium else { return }
        present(from: vc)
    }

    private func present(from vc: UIViewController?) {
        guard let ad = interstitial, let root = vc ?? topViewController() else { return }
        ad.present(from: root)
        isReady = false
    }

    // MARK: - Rewarded (bonus swipes)

    func loadRewarded() async {
        do {
            rewardedAd = try await RewardedAd.load(with: rewardedAdUnitID, request: Request())
            isRewardedReady = true
            rewardedRetryDelay = 2
        } catch {
            isRewardedReady = false
            try? await Task.sleep(nanoseconds: rewardedRetryDelay * 1_000_000_000)
            rewardedRetryDelay = min(rewardedRetryDelay * 2, 64)
            await loadRewarded()
        }
    }

    // `onEarned` only fires if the user watches through to completion — never
    // for a skip/early dismiss — matching AdMob's own reward semantics.
    func showRewarded(from vc: UIViewController? = nil, onEarned: @escaping () -> Void) {
        guard isRewardedReady, let ad = rewardedAd, let root = vc ?? topViewController() else { return }
        isRewardedReady = false
        ad.present(from: root) {
            // The SDK doesn't guarantee this fires on the main thread.
            Task { @MainActor in onEarned() }
        }
        Task { await self.loadRewarded() }
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
