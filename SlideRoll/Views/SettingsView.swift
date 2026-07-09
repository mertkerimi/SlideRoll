import SwiftUI
import Photos
import PhotosUI

struct SettingsView: View {
    @Environment(LanguageManager.self) var lm
    @Environment(NotificationManager.self) var notif
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(SubscriptionManager.self) var subManager
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false

    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            backgroundGlows

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    appHeaderCard
                        .cardEntrance(appeared: appeared, delay: 0.0)

                    subscriptionCard
                        .cardEntrance(appeared: appeared, delay: 0.05)

                    sectionCard(header: lm.s.themeColor) {
                        colorPalette
                    }
                    .cardEntrance(appeared: appeared, delay: 0.07)

                    sectionCard(header: lm.s.appearanceSection) {
                        appearancePicker
                    }
                    .cardEntrance(appeared: appeared, delay: 0.14)

                    sectionCard(header: lm.s.languageLabel) {
                        NavigationLink {
                            LanguageSelectionView().environment(lm)
                        } label: {
                            settingsRow(
                                icon: "globe", iconColor: Theme.accent,
                                title: lm.s.languageLabel,
                                trailing: AnyView(
                                    HStack(spacing: 6) {
                                        Text(lm.selected.flag)
                                            .font(.system(size: 16))
                                        Text(lm.selected.displayName)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .cardEntrance(appeared: appeared, delay: 0.21)

                    if vm.authStatus == .limited {
                        sectionCard(header: lm.s.limitedAccessTitle, footer: lm.s.limitedAccessSub) {
                            limitedAddMoreRow
                            Divider().padding(.horizontal, 16)
                            limitedFullAccessRow
                        }
                        .cardEntrance(appeared: appeared, delay: 0.28)
                    }

                    sectionCard(header: lm.s.notificationsSection) {
                        notificationRow
                    }
                    .cardEntrance(appeared: appeared, delay: 0.28)

                    sectionCard(header: lm.s.aboutSection) {
                        aboutRows
                    }
                    .cardEntrance(appeared: appeared, delay: 0.35)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environment(subManager).environment(lm)
        }
        .task { await notif.refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await notif.refreshStatus() }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Background

    private var backgroundGlows: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.10))
                .frame(width: 260)
                .blur(radius: 80)
                .offset(x: -110, y: -280)
            Circle()
                .fill(Theme.accentEnd.opacity(0.07))
                .frame(width: 200)
                .blur(radius: 60)
                .offset(x: 130, y: 100)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        let isTR = lm.selected == .turkish
        return Button { if !subManager.isPremium { showPaywall = true } } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(subManager.isPremium ? Theme.accent.opacity(0.15) : Theme.surface)
                        .frame(width: 44, height: 44)
                    Image(systemName: subManager.isPremium ? "crown.fill" : "crown")
                        .font(.system(size: 20))
                        .foregroundStyle(subManager.isPremium ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.textSecondary))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(subManager.isPremium ? "Premium" : (isTR ? "Ücretsiz Plan" : "Free Plan"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if subManager.isPremium {
                        if let expiry = subManager.subscriptionExpiryDate {
                            let formatter: DateFormatter = {
                                let f = DateFormatter()
                                f.dateStyle = .medium
                                f.timeStyle = .none
                                return f
                            }()
                            Text((isTR ? "Yenileme: " : "Renews: ") + formatter.string(from: expiry))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if let pid = subManager.activeSubscriptionProductID {
                            let planName: String = {
                                switch pid {
                                case SubscriptionManager.weeklyID:  return isTR ? "Haftalık Plan" : "Weekly Plan"
                                case SubscriptionManager.monthlyID: return isTR ? "Aylık Plan" : "Monthly Plan"
                                case SubscriptionManager.yearlyID:  return isTR ? "Yıllık Plan" : "Yearly Plan"
                                default: return pid
                                }
                            }()
                            Text(planName)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        Text(isTR ? "Premium'a geç" : "Upgrade to Premium")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.accent)
                    }
                }

                Spacer()

                if !subManager.isPremium {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(subManager.isPremium ? Theme.accent.opacity(0.3) : Theme.border, lineWidth: subManager.isPremium ? 1.5 : 1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - App Header Card

    private var appHeaderCard: some View {
        HStack(spacing: 16) {
            Image("SplashIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("SlideRoll")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(lm.s.versionLabel + " " + appVersion)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
    }

    // MARK: - Section Card Builder

    @ViewBuilder
    private func sectionCard(header: String, footer: String? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .tracking(0.5)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
            )

            if let footer {
                Text(footer)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Settings Row Helper

    private func settingsRow(icon: String, iconColor: Color, title: String, trailing: AnyView) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Notification Row

    private var notificationRow: some View {
        let isOn = notif.permissionStatus == .authorized || notif.permissionStatus == .provisional
        return Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            settingsRow(
                icon: isOn ? "bell.fill" : "bell.slash.fill",
                iconColor: isOn ? Theme.orange : Theme.textTertiary,
                title: lm.s.notificationsSection,
                trailing: AnyView(
                    HStack(spacing: 4) {
                        Text(isOn ? lm.s.notifOn : lm.s.notifOff)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isOn ? Theme.green : Theme.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Limited Access Rows

    @State private var limitedHostVC: UIViewController?

    private var limitedAddMoreRow: some View {
        Button {
            guard let vc = limitedHostVC else { return }
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: vc) { _ in
                Task { await vm.loadPhotos() }
            }
        } label: {
            settingsRow(
                icon: "photo.badge.plus", iconColor: Theme.accent,
                title: lm.s.limitedAddMore,
                trailing: AnyView(
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                )
            )
        }
        .buttonStyle(.plain)
        .background { ViewControllerFinder { limitedHostVC = $0 } }
    }

    private var limitedFullAccessRow: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            settingsRow(
                icon: "lock.open.fill", iconColor: Theme.accent,
                title: lm.s.limitedFullAccess,
                trailing: AnyView(
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - About Rows

    private static let privacyPolicyURL = URL(string: "https://mrtkrm.com/slideroll/privacy")!
    private static let supportURL = URL(string: "https://mrtkrm.com/slideroll/support")!

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    @ViewBuilder
    private var aboutRows: some View {
        let s = lm.s

        Link(destination: Self.privacyPolicyURL) {
            settingsRow(
                icon: "hand.raised.fill", iconColor: Theme.red,
                title: s.privacyPolicy,
                trailing: AnyView(
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                )
            )
        }
        .buttonStyle(.plain)

        Divider().padding(.horizontal, 16)

        Button {
            openURL(Self.supportURL)
        } label: {
            settingsRow(
                icon: "envelope.fill", iconColor: Theme.accent,
                title: s.contactSupport,
                trailing: AnyView(
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                )
            )
        }
        .buttonStyle(.plain)

    }

    // MARK: - Appearance Picker

    @Namespace private var appearanceNS

    private var appearancePicker: some View {
        let s = lm.s
        let modes: [(AppearanceMode, String, String)] = [
            (.system, "circle.lefthalf.filled", s.appearanceSystem),
            (.light,  "sun.max.fill",            s.appearanceLight),
            (.dark,   "moon.fill",               s.appearanceDark),
        ]
        return HStack(spacing: 0) {
            ForEach(Array(modes.enumerated()), id: \.1.0) { index, item in
                let (mode, icon, label) = item
                let selected = lm.appearanceMode == mode
                Button {
                    withAnimation(.smooth(duration: 0.4)) {
                        lm.appearanceMode = mode
                    }
                } label: {
                    ZStack {
                        if selected {
                            let big: CGFloat = 10
                            let small: CGFloat = 4
                            let isFirst = index == 0
                            let isLast  = index == modes.count - 1
                            UnevenRoundedRectangle(
                                topLeadingRadius:     isFirst ? big : small,
                                bottomLeadingRadius:  isFirst ? big : small,
                                bottomTrailingRadius: isLast  ? big : small,
                                topTrailingRadius:    isLast  ? big : small,
                                style: .continuous
                            )
                            .fill(Theme.accent)
                            .padding(.leading, isFirst ? -4 : 0)
                            .padding(.trailing, isLast ? -4 : 0)
                            .padding(.vertical, -4)
                            .matchedGeometryEffect(id: "pill", in: appearanceNS)
                            .shadow(color: Theme.accent.opacity(0.4), radius: 8, y: 3)
                        }
                        VStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selected ? .white : Theme.textSecondary)
                            Text(label)
                                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white : Theme.textSecondary)
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Color Palette

    private var colorPalette: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(ColorTheme.allCases) { theme in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        lm.selectedTheme = theme
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(theme.gradient)
                                .frame(width: 40, height: 40)
                                .shadow(color: theme.accent.opacity(lm.selectedTheme == theme ? 0.55 : 0.25),
                                        radius: lm.selectedTheme == theme ? 10 : 5, y: 3)
                                .scaleEffect(lm.selectedTheme == theme ? 1.12 : 1.0)
                                .animation(.spring(response: 0.3), value: lm.selectedTheme)

                            if lm.selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        Text(theme.displayName(in: lm.selected))
                            .font(.system(size: 9, weight: lm.selectedTheme == theme ? .semibold : .regular))
                            .foregroundStyle(lm.selectedTheme == theme ? theme.accent : Theme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - Card Entrance Modifier

private struct CardEntrance: ViewModifier {
    let appeared: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay), value: appeared)
    }
}

private extension View {
    func cardEntrance(appeared: Bool, delay: Double) -> some View {
        modifier(CardEntrance(appeared: appeared, delay: delay))
    }
}
