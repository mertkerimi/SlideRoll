import SwiftUI

struct LanguageSelectionView: View {
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    // Recommended = English + device languages we support + current selection.
    private var recommended: [AppLanguage] {
        var result: [AppLanguage] = [.english]
        for code in Locale.preferredLanguages {
            let two = String(code.prefix(2)).lowercased()
            if let lang = AppLanguage(rawValue: two), !result.contains(lang) {
                result.append(lang)
            }
        }
        if !result.contains(lm.selected) { result.append(lm.selected) }
        return result
    }

    private var others: [AppLanguage] {
        let rec = Set(recommended)
        return AppLanguage.allCases.filter { !rec.contains($0) }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            List {
                Section {
                    ForEach(recommended) { row($0) }
                } header: {
                    sectionHeader(lm.s.languagesRecommended)
                }

                if !others.isEmpty {
                    Section {
                        ForEach(others) { row($0) }
                    } header: {
                        sectionHeader(lm.s.languagesOther)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 40, for: .scrollContent)
        }
        .navigationTitle(lm.s.languageLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .textCase(nil)
    }

    private func row(_ lang: AppLanguage) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { lm.selected = lang }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { dismiss() }
        } label: {
            HStack(spacing: 14) {
                Text(lang.flag)
                    .font(.system(size: 28))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(lang.localizedName(in: lm.selected))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if lm.selected == lang {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
