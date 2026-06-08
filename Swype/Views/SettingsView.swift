import SwiftUI

struct SettingsView: View {
    @Environment(LanguageManager.self) var lm

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
            }
            .scrollContentBackground(.hidden)
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
