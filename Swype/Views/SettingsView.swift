import SwiftUI

struct SettingsView: View {
    @Environment(LanguageManager.self) var lm
    @Environment(NotificationManager.self) var notif

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

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

                // MARK: Language
                Section {
                    ForEach(AppLanguage.allCases) { lang in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                lm.selected = lang
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(lang.flag)
                                    .font(.system(size: 26))
                                Text(lang.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if lm.selected == lang {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Theme.accent)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
            }
            .scrollContentBackground(.hidden)
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

            #if DEBUG
            if notif.enabled {
                Button {
                    notif.cancelAll()
                    notif.reschedule(language: lm.selected)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.orange)
                        Text("Test — her 10 saniyede 6 bildirim gönder")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.orange)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            #endif
        }
    }

    // MARK: - Color Palette

    private var colorPalette: some View {
        HStack(spacing: 0) {
            ForEach(ColorTheme.allCases) { theme in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        lm.selectedTheme = theme
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(theme.gradient)
                                .frame(width: 42, height: 42)
                                .shadow(color: theme.accent.opacity(0.4), radius: 8, y: 3)

                            if lm.selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        Text(theme.displayName)
                            .font(.system(size: 10, weight: lm.selectedTheme == theme ? .semibold : .regular))
                            .foregroundStyle(lm.selectedTheme == theme ? theme.accent : Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}
