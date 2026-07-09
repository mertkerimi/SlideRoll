import StoreKit

@Observable
@MainActor
final class SubscriptionManager {

    static let weeklyID  = "com.mertkerimi.slideroll.weekly"
    static let monthlyID = "com.mertkerimi.slideroll.monthly"
    static let yearlyID  = "com.mertkerimi.slideroll.yearly"
    static let freeSwipeLimit = 200

    private static let productIDs = [weeklyID, monthlyID, yearlyID]

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoadingProducts = false
    var productLoadFailed = false
    var isPurchasing = false
    var dailySwipeCount: Int = 0
    var activeSubscriptionProductID: String? = nil
    var subscriptionExpiryDate: Date? = nil

    var isPremium: Bool { !purchasedProductIDs.isEmpty }

    var hasReachedDailyLimit: Bool {
        !isPremium && dailySwipeCount >= Self.freeSwipeLimit
    }

    private var updatesTask: Task<Void, Never>?

    init() {
        loadDailySwipeCount()
        updatesTask = Task { await listenForTransactions() }
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
            print("StoreKit product load error: \(error)")
            productLoadFailed = true
        }
        await updatePurchasedProducts()
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true
        case .userCancelled:
            return false
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
        } catch {
            print("Restore failed: \(error)")
        }
    }

    // MARK: - Daily Swipe Tracking

    func recordSwipe() {
        dailySwipeCount += 1
        saveDailySwipeCount()
    }

    private func loadDailySwipeCount() {
        let stored   = UserDefaults.standard.integer(forKey: "dailySwipeCount_v1")
        let storedDate = UserDefaults.standard.string(forKey: "dailySwipeDate_v1") ?? ""
        let today    = todayString()
        if storedDate == today {
            dailySwipeCount = stored
        } else {
            dailySwipeCount = 0
            UserDefaults.standard.set(today, forKey: "dailySwipeDate_v1")
            UserDefaults.standard.set(0,     forKey: "dailySwipeCount_v1")
        }
    }

    private func saveDailySwipeCount() {
        UserDefaults.standard.set(dailySwipeCount, forKey: "dailySwipeCount_v1")
        UserDefaults.standard.set(todayString(),   forKey: "dailySwipeDate_v1")
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
            if let t = try? checkVerified(result) {
                purchased.insert(t.productID)
                if latestExpiry == nil || (t.expirationDate ?? .distantFuture) > (latestExpiry ?? .distantPast) {
                    latestProductID = t.productID
                    latestExpiry = t.expirationDate
                }
            }
        }
        purchasedProductIDs = purchased
        activeSubscriptionProductID = latestProductID
        subscriptionExpiryDate = latestExpiry
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let t = try? checkVerified(result) {
                await updatePurchasedProducts()
                await t.finish()
            }
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
