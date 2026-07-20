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
    // again — defaults to true until checked so behavior is unchanged if the
    // check hasn't completed yet.
    var isEligibleForWeeklyTrial = true
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
            await refreshTrialEligibility()
        } catch {
            productLoadFailed = true
        }
        await updatePurchasedProducts()
    }

    private func refreshTrialEligibility() async {
        guard let weekly = products.first(where: { $0.id == Self.weeklyID }),
              let subscription = weekly.subscription else { return }
        isEligibleForWeeklyTrial = await subscription.isEligibleForIntroOffer
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
                // expirationDate can be nil in Xcode sandbox — fall back to 7 days
                let expiry = t.expirationDate ?? Date().addingTimeInterval(7 * 24 * 3600)
                subscriptionExpiryDate = expiry
                UserDefaults.standard.set(t.productID, forKey: Self.cachedProductIDKey)
                UserDefaults.standard.set(expiry,      forKey: Self.cachedExpiryKey)
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
