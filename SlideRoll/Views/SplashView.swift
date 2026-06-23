import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0
    @State private var pulse1Scale: CGFloat = 1.0
    @State private var pulse1Opacity: Double = 0
    @State private var pulse2Scale: CGFloat = 1.0
    @State private var pulse2Opacity: Double = 0
    @State private var textOffset: CGFloat = 24
    @State private var textOpacity: Double = 0
    @State private var containerOpacity: Double = 1

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Background ambient glows
            Circle()
                .fill(Theme.accent.opacity(0.18))
                .frame(width: 340)
                .blur(radius: 90)
                .offset(x: -80, y: -200)
                .opacity(glowOpacity)

            Circle()
                .fill(Theme.accentEnd.opacity(0.12))
                .frame(width: 260)
                .blur(radius: 70)
                .offset(x: 110, y: 120)
                .opacity(glowOpacity)

            VStack(spacing: 28) {
                ZStack {
                    // Pulse ring 2 (outer, slower)
                    RoundedRectangle(cornerRadius: 24 * pulse2Scale, style: .continuous)
                        .stroke(Color(red: 0.22, green: 0.35, blue: 0.95).opacity(0.15), lineWidth: 1.5)
                        .frame(width: 110, height: 110)
                        .scaleEffect(pulse2Scale)
                        .opacity(pulse2Opacity)

                    // Pulse ring 1 (inner, faster)
                    RoundedRectangle(cornerRadius: 24 * pulse1Scale, style: .continuous)
                        .stroke(Color(red: 0.22, green: 0.35, blue: 0.95).opacity(0.25), lineWidth: 2)
                        .frame(width: 110, height: 110)
                        .scaleEffect(pulse1Scale)
                        .opacity(pulse1Opacity)

                    // Icon
                    Image("SplashIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color(red: 0.22, green: 0.35, blue: 0.95).opacity(0.5), radius: 36, y: 14)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                }

                // App name + tagline
                VStack(spacing: 10) {
                    Text("SlideRoll")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Photo Cleaner")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .tracking(1.2)
                }
                .offset(y: textOffset)
                .opacity(textOpacity)
            }
        }
        .opacity(containerOpacity)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Icon springs in
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        // Background glows fade in
        withAnimation(.easeOut(duration: 0.8)) {
            glowOpacity = 1.0
        }

        // Text slides up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                textOffset = 0
                textOpacity = 1.0
            }
        }

        // Pulse ring 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pulse1Opacity = 0.9
            withAnimation(.easeOut(duration: 1.0)) {
                pulse1Scale = 2.2
                pulse1Opacity = 0
            }
        }

        // Pulse ring 2 (staggered)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            pulse2Opacity = 0.7
            withAnimation(.easeOut(duration: 1.1)) {
                pulse2Scale = 2.6
                pulse2Opacity = 0
            }
        }

        // Fade out and finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeInOut(duration: 0.45)) {
                containerOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onFinished()
            }
        }
    }
}
