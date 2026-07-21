import StoreKit

@Observable
@MainActor
final class SubscriptionManager {

    static let weeklyID  = "com.mertkerimi.slideroll.weekly"
    static let monthlyID = "com.mertkerimi.slideroll.monthly"
    static let yearlyID  = "com.mertkerimi.slideroll.yearly"
    static let freeSwipeLimit = 300
    // Rewarded-ad bonus: free users can watch up to 2 ads/day to unlock 100
    // more swipes each (so up to 500 total/day) — capped, not infinite, so it
    // never fully replaces the "unlimited, no ads" pitch of subscribing.
    static let bonusSwipeAmount = 100
    static let maxDailyBonusGrants = 2

    private static let productIDs = [weeklyID, monthlyID, yearlyID]

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoadingProducts = false
    var productLoadFailed = false
    var isPurchasing = false
    // Whether the weekly plan's 7-day trial is still available to this user.
    // StoreKit only grants an introductory offer once per subscription group,
    // so someone who already used (and ended) their trial is not eligible
    // again — defaults to false (safe/conservative) until the real check
    // completes, so the paywall never flashes "Start Free Trial" to someone
    // who isn't actually eligible. isCheckingTrialEligibility gates the UI
    // during that check so nothing is tappable with an unverified state.
    var isEligibleForWeeklyTrial = false
    var isCheckingTrialEligibility = true
    var dailySwipeCount: Int = 0
    var bonusSwipesEarnedToday: Int = 0
    var activeSubscriptionProductID: String? = nil
    var subscriptionExpiryDate: Date? = nil

    // Cached expiry survives app restarts — StoreKit verification happens after
    private static let cachedExpiryKey     = "premiumExpiryCache_v1"
    private static let cachedProductIDKey  = "premiumProductIDCache_v1"

    var isPremium: Bool { !purchasedProductIDs.isEmpty }

    private var effectiveDailyLimit: Int { Self.freeSwipeLimit + bonusSwipesEarnedToday }

    var hasReachedDailyLimit: Bool {
        !isPremium && dailySwipeCount >= effectiveDailyLimit
    }

    // Whether there's still a rewarded-ad bonus left to offer today.
    var canEarnBonusSwipes: Bool {
        !isPremium && bonusSwipesEarnedToday < Self.bonusSwipeAmount * Self.maxDailyBonusGrants
    }

    // Call after a rewarded ad finishes and the user actually earned the reward.
    func grantBonusSwipes() {
        guard canEarnBonusSwipes else { return }
        bonusSwipesEarnedToday += Self.bonusSwipeAmount
        saveDailySwipeCount()
    }

    private var updatesTask: Task<Void, Never>?

    init() {
        restoreCachedPremium()
        loadDailySwipeCount()
        updatesTask = Task { await listenForTransactions() }
    }

    // Restore premium state immediately from cache so UI shows correct state
    // before StoreKit verification completes. updatePurchasedProducts() will
    // overwrite this with the verified result shortly after launch.
    private func restoreCachedPremium() {
        guard
            let id = UserDefaults.standard.string(forKey: Self.cachedProductIDKey),
            let expiry = UserDefaults.standard.object(forKey: Self.cachedExpiryKey) as? Date,
            expiry > Date()
        else { return }
        purchasedProductIDs.insert(id)
        activeSubscriptionProductID = id
        subscriptionExpiryDate = expiry
    }

    // MARK: - Products

    func loadProducts() async {
        isLoadingProducts = true
        productLoadFailed = false
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted {
                (Self.productIDs.firstIndex(of: $0.id) ?? 0) < (Self.productIDs.firstIndex(of: $1.id) ?? 0)
            }
            productLoadFailed = products.isEmpty
        } catch {
            productLoadFailed = true
        }
        await updatePurchasedProducts()
    }

    // Call right before showing the paywall's trial-vs-full-price copy, not
    // from loadProducts() (which also runs on every app launch to check
    // isPremium for ads/daily-limit gating) — AppStore.sync() can prompt for
    // re-authentication, so it should only fire when we're actually about to
    // decide "Start Free Trial" vs "Get Premium", not on every cold start.
    func refreshTrialEligibilityIfNeeded() async {
        isCheckingTrialEligibility = true
        defer { isCheckingTrialEligibility = false }
        // Force a fresh sync with Apple's servers before reading any
        // entitlement/eligibility state below — the on-device StoreKit cache
        // can be stale or missing older history (like an already-used trial
        // from weeks ago), which is what let isEligibleForIntroOffer AND the
        // latestTransaction cross-check both miss a real prior purchase.
        try? await AppStore.sync()
        await updatePurchasedProducts()
        await refreshTrialEligibility()
    }

    private func refreshTrialEligibility() async {
        guard let weekly = products.first(where: { $0.id == Self.weeklyID }),
              let subscription = weekly.subscription else { return }

        // isEligibleForIntroOffer is a documented-unreliable StoreKit 2 API —
        // multiple unresolved Apple Developer Forum threads report it can
        // return true for users who've already used their trial (and vice
        // versa). Cross-check the product's own transaction history: any past
        // verified transaction for this exact product means they've
        // definitely had it before, regardless of what the eligibility flag
        // claims.
        let rawEligible = await subscription.isEligibleForIntroOffer
        var eligible = rawEligible
        let latest = await weekly.latestTransaction
        var latestFound = false
        if let latest, case .verified = latest {
            latestFound = true
            eligible = false
        }
        isEligibleForWeeklyTrial = eligible
        #if DEBUG
        print("[SubscriptionManager] rawIsEligibleForIntroOffer=\(rawEligible), latestTransactionFound=\(latestFound), finalEligible=\(eligible), purchasedProductIDs=\(purchasedProductIDs)")
        #endif
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            // Finish the transaction regardless of verification status so it
            // doesn't stay stuck in the queue (causes "already subscribed" error)
            switch verification {
            case .verified(let t):      await t.finish()
            case .unverified(let t, _): await t.finish()
            }
            // Refresh entitlements from StoreKit
            await updatePurchasedProducts()
            // Fallback: entitlements may not propagate immediately in sandbox or
            // on slow networks. Use the verified transaction data directly.
            if purchasedProductIDs.isEmpty, case .verified(let t) = verification {
                purchasedProductIDs.insert(t.productID)
                activeSubscriptionProductID = t.productID
                // expirationDate can be nil (seen in Sandbox). Only cache a
                // real expiry — guessing one (e.g. a flat 7 days) is actively
                // wrong for Sandbox's massively accelerated renewal periods
                // (a "week" can expire in ~3 minutes there), and would make
                // the app keep showing premium long after the real
                // subscription ended. Without a cached expiry,
                // updatePurchasedProducts() / Transaction.currentEntitlements
                // remains the source of truth on next launch.
                if let expiry = t.expirationDate {
                    subscriptionExpiryDate = expiry
                    UserDefaults.standard.set(t.productID, forKey: Self.cachedProductIDKey)
                    UserDefaults.standard.set(expiry,      forKey: Self.cachedExpiryKey)
                }
            }
            return isPremium
        case .userCancelled:
            try? await AppStore.sync()
            await updatePurchasedProducts()
            return isPremium
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {}
    }

    // MARK: - Daily Swipe Tracking

    func recordSwipe() {
        dailySwipeCount += 1
        saveDailySwipeCount()
    }

    private func loadDailySwipeCount() {
        let stored       = UserDefaults.standard.integer(forKey: "dailySwipeCount_v1")
        let storedBonus  = UserDefaults.standard.integer(forKey: "bonusSwipesEarnedToday_v1")
        let storedDate   = UserDefaults.standard.string(forKey: "dailySwipeDate_v1") ?? ""
        let today        = todayString()
        if storedDate == today {
            dailySwipeCount = stored
            bonusSwipesEarnedToday = storedBonus
        } else {
            dailySwipeCount = 0
            bonusSwipesEarnedToday = 0
            UserDefaults.standard.set(today, forKey: "dailySwipeDate_v1")
            UserDefaults.standard.set(0,     forKey: "dailySwipeCount_v1")
            UserDefaults.standard.set(0,     forKey: "bonusSwipesEarnedToday_v1")
        }
    }

    private func saveDailySwipeCount() {
        UserDefaults.standard.set(dailySwipeCount,         forKey: "dailySwipeCount_v1")
        UserDefaults.standard.set(bonusSwipesEarnedToday,   forKey: "bonusSwipesEarnedToday_v1")
        UserDefaults.standard.set(todayString(),            forKey: "dailySwipeDate_v1")
    }

    private func todayString() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Transaction Listening

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var latestProductID: String? = nil
        var latestExpiry: Date? = nil
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result {
                guard t.revocationDate == nil else { continue }
                purchased.insert(t.productID)
                let expiry = t.expirationDate ?? .distantFuture
                if latestExpiry == nil || expiry > (latestExpiry ?? .distantPast) {
                    latestProductID = t.productID
                    latestExpiry = t.expirationDate
                }
            }
        }

        if !purchased.isEmpty {
            // StoreKit confirmed an active entitlement — update everything
            purchasedProductIDs = purchased
            activeSubscriptionProductID = latestProductID
            subscriptionExpiryDate = latestExpiry
            if let id = latestProductID, let expiry = latestExpiry, expiry > Date() {
                UserDefaults.standard.set(id,     forKey: Self.cachedProductIDKey)
                UserDefaults.standard.set(expiry, forKey: Self.cachedExpiryKey)
            }
        } else {
            // StoreKit returned nothing (timing issue in sandbox, or slow network).
            // Only clear premium if the local cache is also expired — otherwise
            // keep the cached state and let the next verification cycle decide.
            let cachedExpiry = UserDefaults.standard.object(forKey: Self.cachedExpiryKey) as? Date
            if let expiry = cachedExpiry, expiry > Date() {
                // Cache is still valid — don't wipe premium state
            } else {
                // Cache expired too — subscription is genuinely gone
                purchasedProductIDs = []
                activeSubscriptionProductID = nil
                subscriptionExpiryDate = nil
                UserDefaults.standard.removeObject(forKey: Self.cachedProductIDKey)
                UserDefaults.standard.removeObject(forKey: Self.cachedExpiryKey)
            }
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let t) = result else { continue }
            await t.finish()
            await updatePurchasedProducts()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.failedVerification
        case .verified(let safe): return safe
        }
    }
}

enum SubscriptionError: Error {
    case failedVerification
}
