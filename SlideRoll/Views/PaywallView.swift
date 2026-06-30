import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionManager.self) var subManager
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    @State private var selectedProductID = SubscriptionManager.weeklyID
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isRestoring = false

    private var isTR: Bool { lm.selected == .turkish }

    private var selectedProduct: Product? {
        subManager.products.first { $0.id == selectedProductID }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            backgroundGlows

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        titleSection
                        featureTable
                        planPicker
                        subscribeButton
                        if selectedProductID == SubscriptionManager.weeklyID {
                            trialTimeline
                        }
                        footerNote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await subManager.loadProducts() }
        .alert(isTR ? "Hata" : "Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: subManager.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            }
            Spacer()
            Button {
                Task { isRestoring = true; await subManager.restorePurchases(); isRestoring = false }
            } label: {
                if isRestoring {
                    ProgressView().tint(Theme.textSecondary).scaleEffect(0.8)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Theme.surface, in: Circle())
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.15)).frame(width: 72, height: 72)
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.accentGradient)
            }
            Text(isTR ? "Premium'a Yükselt" : "Upgrade to Premium")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(isTR ? "Reklamsız, sınırsız temizleme deneyimi" : "Ad-free, unlimited cleaning experience")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    // MARK: - Feature Table

    private var featureTable: some View {
        VStack(spacing: 0) {
            tableHeader
            Divider().background(Theme.border)
            featureRow(isTR ? "Reklamsız Deneyim"     : "Ad-Free Experience",     free: false, premium: true)
            featureRow(isTR ? "Günlük Kaydırma Limiti": "Daily Swipe Limit",       freeText: "50", premiumText: "∞")
            featureRow(isTR ? "Albüm Temizleme"        : "Album Cleaning",          free: false, premium: true)
            featureRow(isTR ? "Duplicate Finder"       : "Duplicate Finder",        free: false, premium: true, isLast: true)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private var tableHeader: some View {
        HStack {
            Spacer()
            Text(isTR ? "Ücretsiz" : "Free")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 72, alignment: .center)
            Text("Premium")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func featureRow(_ title: String, free: Bool, premium: Bool, isLast: Bool = false) -> some View {
        featureRowContent(title: title, freeContent: freeIcon(free), premiumContent: premiumIcon(premium), isLast: isLast)
    }

    private func featureRow(_ title: String, freeText: String, premiumText: String, isLast: Bool = false) -> some View {
        featureRowContent(
            title: title,
            freeContent: Text(freeText).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textSecondary),
            premiumContent: Text(premiumText).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent),
            isLast: isLast
        )
    }

    private func featureRowContent<F: View, P: View>(title: String, freeContent: F, premiumContent: P, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            if !isLast { Divider().background(Theme.border) }
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                freeContent.frame(width: 72, alignment: .center)
                premiumContent.frame(width: 72, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
    }

    private func freeIcon(_ value: Bool) -> some View {
        Image(systemName: value ? "checkmark" : "xmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(value ? Theme.green : Theme.textTertiary)
    }

    private func premiumIcon(_ value: Bool) -> some View {
        Image(systemName: value ? "checkmark" : "xmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(value ? Theme.green : Theme.textTertiary)
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        VStack(spacing: 8) {
            if subManager.isLoadingProducts {
                ProgressView().tint(Theme.accent).padding()
            } else if subManager.productLoadFailed || subManager.products.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.textTertiary)
                    Text(isTR ? "Ürünler yüklenemedi" : "Couldn't load products")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Button {
                        Task { await subManager.loadProducts() }
                    } label: {
                        Text(isTR ? "Yeniden Dene" : "Retry")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Theme.accent, in: Capsule())
                    }
                }
                .padding(.vertical, 12)
            } else {
                ForEach(subManager.products, id: \.id) { product in
                    planCard(product)
                }
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected   = selectedProductID == product.id
        let isWeekly     = product.id == SubscriptionManager.weeklyID

        return Button { selectedProductID = product.id } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Theme.accent).frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(planTitle(product))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(planDescriptor(product))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if isWeekly {
                        Text(isTR ? "1 hafta ücretsiz" : "1 week free")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.accentGradient, in: Capsule())
                        Text(isTR ? "sonra " + pricePeriod(product) : "then " + pricePeriod(product))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    } else {
                        Text(product.displayPrice)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Theme.accent : Theme.textPrimary)
                        Text(periodLabel(product))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.08) : Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func planTitle(_ product: Product) -> String {
        switch product.id {
        case SubscriptionManager.weeklyID:  return isTR ? "Haftalık Plan"  : "Weekly Plan"
        case SubscriptionManager.monthlyID: return isTR ? "Aylık Plan"     : "Monthly Plan"
        case SubscriptionManager.yearlyID:  return isTR ? "Yıllık Plan"    : "Yearly Plan"
        default: return product.displayName
        }
    }

    private func planDescriptor(_ product: Product) -> String {
        switch product.id {
        case SubscriptionManager.weeklyID:  return isTR ? "7 gün ücretsiz dene" : "Try free for 7 days"
        case SubscriptionManager.monthlyID: return isTR ? "Her ay yenilenir"    : "Renews monthly"
        case SubscriptionManager.yearlyID:  return isTR ? "En iyi değer"        : "Best value"
        default: return ""
        }
    }

    private func pricePeriod(_ product: Product) -> String {
        isTR ? "\(product.displayPrice)/hafta" : "\(product.displayPrice)/week"
    }

    private func periodLabel(_ product: Product) -> String {
        switch product.id {
        case SubscriptionManager.monthlyID: return isTR ? "/ay"  : "/month"
        case SubscriptionManager.yearlyID:  return isTR ? "/yıl" : "/year"
        default: return ""
        }
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task {
                do {
                    _ = try await subManager.purchase(product)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } label: {
            ZStack {
                if subManager.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    let isWeekly = selectedProductID == SubscriptionManager.weeklyID
                    Text(isWeekly
                         ? (isTR ? "Ücretsiz Denemeyi Başlat" : "Start Free Trial")
                         : (isTR ? "Premium'a Geç" : "Get Premium"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.4), radius: 16, y: 8)
        }
        .disabled(subManager.isPurchasing || subManager.isLoadingProducts || selectedProduct == nil)
    }

    // MARK: - Trial Timeline

    private var trialTimeline: some View {
        let weeklyProduct = subManager.products.first { $0.id == SubscriptionManager.weeklyID }
        let price = weeklyProduct?.displayPrice ?? "—"

        return VStack(alignment: .leading, spacing: 0) {
            timelineRow(
                icon: "checkmark.circle.fill",
                color: Theme.green,
                title: isTR ? "Bugün" : "Today",
                subtitle: isTR ? "Ücretsiz denemeniz başlayacak" : "Your free trial begins",
                value: isTR ? "1 Hafta Ücretsiz" : "1 Week Free",
                isLast: false
            )
            timelineRow(
                icon: "clock.fill",
                color: Theme.textTertiary,
                title: isTR ? "7 gün sonra" : "After 7 days",
                subtitle: isTR ? "Premium aboneliğiniz başlayacak" : "Your premium subscription begins",
                value: price,
                isLast: true
            )
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    private func timelineRow(icon: String, color: Color, title: String, subtitle: String, value: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                if !isLast {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 1.5, height: 28)
                        .padding(.top, 4)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color == Theme.green ? Theme.green : Theme.textSecondary)
        }
        .padding(.vertical, isLast ? 0 : 8)
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text(isTR
             ? "Abonelik, dönem sona ermeden 24 saat önce iptal edilmezse otomatik olarak yenilenir. İstediğin zaman App Store ayarlarından iptal edebilirsin."
             : "Subscription renews automatically unless cancelled at least 24 hours before the end of the period. Cancel anytime in App Store settings.")
            .font(.system(size: 10))
            .foregroundStyle(Theme.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: - Background

    private var backgroundGlows: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.08)).frame(width: 300).blur(radius: 80).offset(x: 100, y: -200)
            Circle().fill(Theme.green.opacity(0.05)).frame(width: 200).blur(radius: 60).offset(x: -80, y: 200)
        }
    }
}
