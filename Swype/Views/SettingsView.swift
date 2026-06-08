import SwiftUI

struct SettingsView: View {
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                List {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(lm.s.settings)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lm.s.close) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
