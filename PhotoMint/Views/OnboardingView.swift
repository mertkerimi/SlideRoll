import SwiftUI

struct OnboardingView: View {
    let onFinished: () -> Void
    @Environment(LanguageManager.self) var lm
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            backgroundGlows

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    Button(lm.s.onboardingSkip, action: onFinished)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                // Pages
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    swipePage.tag(1)
                    featuresPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Dots + button
                VStack(spacing: 28) {
                    pageDots
                    actionButton
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        let s = lm.s
        return VStack(spacing: 32) {
            Spacer()
            Image("SplashIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color(red: 0.22, green: 0.35, blue: 0.95).opacity(0.45), radius: 32, y: 12)
                .scaleEffect(currentPage == 0 ? 1 : 0.9)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPage)

            VStack(spacing: 14) {
                Text(s.ob1Title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(s.ob1Desc)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Page 2: Swipe Gestures

    private var swipePage: some View {
        let s = lm.s
        return VStack(spacing: 28) {
            Spacer()

            // Mini card illustration
            ZStack {
                // Card shadow layers
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surfaceHigh)
                    .frame(width: 140, height: 180)
                    .scaleEffect(0.9).offset(y: 12)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
                    .frame(width: 140, height: 180)
                    .overlay(
                        Image(systemName: "photo.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.textTertiary.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )

                // Left arrow
                swipeHint(icon: "arrow.left", label: s.ob2Delete, color: Theme.red)
                    .offset(x: -110)

                // Right arrow
                swipeHint(icon: "arrow.right", label: s.ob2Keep, color: Theme.green)
                    .offset(x: 110)

                // Up arrow
                swipeHint(icon: "arrow.up", label: s.ob2Skip, color: Theme.orange)
                    .offset(y: -120)
            }
            .frame(height: 240)

            VStack(spacing: 12) {
                Text(s.ob2Title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Text(s.ob2Desc)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func swipeHint(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
    }

    // MARK: - Page 3: Features

    private var featuresPage: some View {
        let s = lm.s
        return VStack(spacing: 24) {
            Spacer()

            Text(s.ob3Title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            VStack(spacing: 14) {
                featureRow(icon: "video.fill",             color: Theme.accent,
                           title: s.ob3Feat1Title, desc: s.ob3Feat1Desc)
                featureRow(icon: "heart.fill",             color: .pink,
                           title: s.ob3Feat2Title, desc: s.ob3Feat2Desc)
                featureRow(icon: "square.and.arrow.up.fill", color: Theme.green,
                           title: s.ob3Feat3Title, desc: s.ob3Feat3Desc)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func featureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(desc)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
    }

    // MARK: - Controls

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i == currentPage ? Theme.accent : Theme.surfaceHigh)
                    .frame(width: i == currentPage ? 20 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
            }
        }
    }

    private var actionButton: some View {
        let isLast = currentPage == 2
        let label = isLast ? lm.s.onboardingStart : lm.s.onboardingNext

        return Button {
            if isLast {
                onFinished()
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    currentPage += 1
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 17, weight: .bold))
                if !isLast {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.4), radius: 18, y: 8)
        }
        .animation(.easeInOut(duration: 0.2), value: isLast)
    }

    private var backgroundGlows: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.10))
                .frame(width: 300).blur(radius: 80)
                .offset(x: -100, y: -280)
            Circle()
                .fill(Theme.accentEnd.opacity(0.07))
                .frame(width: 240).blur(radius: 60)
                .offset(x: 120, y: 160)
        }
    }
}
