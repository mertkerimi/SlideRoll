import SwiftUI

// Shown when a free user hits their daily swipe limit but still has a
// rewarded-ad bonus available (SubscriptionManager.canEarnBonusSwipes).
// Offers a capped way to keep going today without subscribing, while still
// leaving subscribing as the only way to remove the daily limit entirely.
struct BonusSwipesPromptView: View {
    @Environment(AdManager.self) var adManager
    @Environment(SubscriptionManager.self) var subManager
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    let onEarnedBonus: () -> Void
    let onGoPremium: () -> Void

    @State private var isShowingAd = false

    private var isTR: Bool { lm.selected == .turkish }

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Theme.border)
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.accentGradient)
            }
            .padding(.top, 4)

            VStack(spacing: 8) {
                Text(isTR ? "Bugünkü kaydırma hakkın bitti" : "You're out of swipes for today")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(isTR
                     ? "Kısa bir reklam izleyerek \(SubscriptionManager.bonusSwipeAmount) kaydırma hakkı daha kazanabilirsin."
                     : "Watch a short ad to unlock \(SubscriptionManager.bonusSwipeAmount) more swipes.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 10) {
                Button { watchAd() } label: {
                    HStack(spacing: 8) {
                        if isShowingAd {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(isTR
                                 ? "Reklam İzle (+\(SubscriptionManager.bonusSwipeAmount))"
                                 : "Watch Ad (+\(SubscriptionManager.bonusSwipeAmount))")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!adManager.isRewardedReady || isShowingAd)
                .opacity(adManager.isRewardedReady ? 1 : 0.5)

                Button {
                    dismiss()
                    onGoPremium()
                } label: {
                    Text(isTR ? "Premium'a Geç" : "Get Premium")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
                }
                .disabled(isShowingAd)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            Button(isTR ? "Kapat" : "Close") { dismiss() }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .disabled(isShowingAd)
                .padding(.top, 2)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(isShowingAd)
    }

    private func watchAd() {
        isShowingAd = true
        adManager.showRewarded {
            subManager.grantBonusSwipes()
            isShowingAd = false
            dismiss()
            onEarnedBonus()
        }
    }
}
