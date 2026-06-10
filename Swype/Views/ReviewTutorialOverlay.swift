import SwiftUI

struct ReviewTutorialOverlay: View {
    let onDismiss: () -> Void
    @Environment(LanguageManager.self) var lm
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 32) {
                // Title
                VStack(spacing: 8) {
                    Text(lm.s.tutorialTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -10)

                // Card with arrows
                ZStack {
                    // Mini card
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 160, height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: "photo.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.white.opacity(0.2))
                        )

                    // Left — Delete
                    tutorialArrow(
                        icon: "arrow.left",
                        label: lm.s.ob2Delete,
                        color: Theme.red
                    )
                    .offset(x: -120)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 20)

                    // Right — Keep
                    tutorialArrow(
                        icon: "arrow.right",
                        label: lm.s.ob2Keep,
                        color: Theme.green
                    )
                    .offset(x: 120)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : -20)

                    // Up — Skip
                    tutorialArrow(
                        icon: "arrow.up",
                        label: lm.s.ob2Skip,
                        color: Theme.orange
                    )
                    .offset(y: -130)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                }
                .frame(height: 280)

                // Dismiss button
                Button(action: onDismiss) {
                    Text(lm.s.tutorialDismiss)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 200)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(Color.white.opacity(0.15))
                                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        )
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func tutorialArrow(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .frame(width: 72)
        }
    }
}
