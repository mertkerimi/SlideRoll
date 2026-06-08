import SwiftUI

struct PermissionView: View {
    let onRequest: () async -> Void
    @Environment(LanguageManager.self) var lm

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Background glow
            Circle()
                .fill(Theme.accent.opacity(0.15))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -60, y: -160)

            Circle()
                .fill(Theme.accentEnd.opacity(0.10))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
                .offset(x: 100, y: 80)

            VStack(spacing: 0) {
                Spacer()

                // Hero icon
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 110, height: 110)
                        .shadow(color: Theme.accent.opacity(0.5), radius: 30, y: 12)

                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 40)

                VStack(spacing: 14) {
                    Text("Swype")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    Text(lm.s.appTagline)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.bottom, 56)

                Spacer()

                VStack(spacing: 14) {
                    // Primary button
                    Button {
                        Task { await onRequest() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(lm.s.allowPhotos)
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Theme.accent.opacity(0.45), radius: 20, y: 8)
                    }

                    // Secondary
                    Button(lm.s.allowInSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
    }
}
