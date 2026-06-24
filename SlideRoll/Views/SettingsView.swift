import SwiftUI

struct SettingsView: View {
    @Environment(LanguageManager.self) var lm
    @Environment(NotificationManager.self) var notif
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            List {
                // MARK: Color Theme
                Section {
                    colorPalette
                } header: {
                    Text(lm.s.themeColor)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(nil)
                }

                // MARK: Appearance
                Section {
                    appearancePicker
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text(lm.s.appearanceSection)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(nil)
                }

                // MARK: Language
                Section {
                    NavigationLink {
                        LanguageSelectionView().environment(lm)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.accent)
                            Text(lm.s.languageLabel)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(lm.selected.displayName)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                } header: {
                    Text(lm.s.languageLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(nil)
                }
                // MARK: Notifications
                Section {
                    notificationRows
                } header: {
                    Text(lm.s.notificationsSection)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(nil)
                }

                // MARK: About / Legal
                Section {
                    aboutRows
                } header: {
                    Text(lm.s.aboutSection)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 96, for: .scrollContent)
        }
        .task { await notif.refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await notif.refreshStatus() }
        }
    }

    // MARK: - Notification Rows

    @ViewBuilder
    private var notificationRows: some View {
        let s = lm.s
        switch notif.permissionStatus {

        case .notDetermined:
            Button {
                Task {
                    let ok = await notif.requestPermission()
                    if ok {
                        notif.enabled = true
                        notif.reschedule(language: lm.selected)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.allowNotifications)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(s.notifPermissionSub)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        case .denied:
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.notifDenied)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text(s.notifDeniedSub)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button(s.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 3)

        default:
            Toggle(isOn: Binding(
                get: { notif.enabled },
                set: { val in
                    notif.enabled = val
                    if val { notif.reschedule(language: lm.selected) }
                    else   { notif.cancelAll() }
                }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.weeklyReminder)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(s.weeklyReminderSub)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .tint(Theme.accent)

        }
    }

    // MARK: - About / Legal Rows

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
            aboutRow(icon: "hand.raised.fill", title: s.privacyPolicy, showChevron: true)
        }
        .buttonStyle(.plain)

        Button {
            openURL(Self.supportURL)
        } label: {
            aboutRow(icon: "envelope.fill", title: s.contactSupport, showChevron: true)
        }
        .buttonStyle(.plain)

        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent).frame(width: 28)
            Text(s.versionLabel)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(appVersion)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 3)
    }

    private func aboutRow(icon: String, title: String, showChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent).frame(width: 28)
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    // MARK: - Appearance Picker

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
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        lm.appearanceMode = mode
                    }
                } label: {
                    let selected = lm.appearanceMode == mode
                    let big: CGFloat = 12
                    let small: CGFloat = 7
                    let isFirst = index == 0
                    let isLast  = index == modes.count - 1
                    let tl: CGFloat = isFirst ? big : small
                    let bl: CGFloat = isFirst ? big : small
                    let tr: CGFloat = isLast  ? big : small
                    let br: CGFloat = isLast  ? big : small
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selected ? .white : Theme.textSecondary)
                        Text(label)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? .white : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: tl, bottomLeadingRadius: bl,
                            bottomTrailingRadius: br, topTrailingRadius: tr,
                            style: .continuous
                        )
                        .fill(selected ? Theme.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
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
        .padding(.vertical, 10)
    }
}
