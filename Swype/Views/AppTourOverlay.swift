import SwiftUI

// MARK: - Anchor Preference

struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [TourTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TourTarget: Anchor<CGRect>], nextValue: () -> [TourTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

enum TourTarget: Hashable {
    case summaryCard, yearCards, monthCards, tabBar
}

extension Notification.Name {
    static let tourNavigateToFirstYear = Notification.Name("tourNavigateToFirstYear")
}

struct TourAnchorModifier: ViewModifier {
    let target: TourTarget
    func body(content: Content) -> some View {
        content.anchorPreference(key: TourAnchorKey.self, value: .bounds) { [target: $0] }
    }
}

extension View {
    func tourAnchor(_ target: TourTarget) -> some View {
        modifier(TourAnchorModifier(target: target))
    }
}

// MARK: - Step Model

private struct TourStep {
    let target: TourTarget
    let title: String
    let desc: String
    let tipBelow: Bool
}

// MARK: - Overlay

struct AppTourOverlay: View {
    let anchors: [TourTarget: Anchor<CGRect>]
    let proxy: GeometryProxy
    let onFinish: () -> Void

    @Environment(LanguageManager.self) var lm
    @State private var stepIndex = 0
    @State private var appeared = false
    @State private var isNavigating = false

    private var steps: [TourStep] {
        let s = lm.s
        return [
            TourStep(target: .summaryCard, title: s.tourStep1Title, desc: s.tourStep1Desc, tipBelow: true),
            TourStep(target: .tabBar,      title: s.tourStep4Title, desc: s.tourStep4Desc, tipBelow: false),
            TourStep(target: .yearCards,   title: s.tourStep2Title, desc: s.tourStep2Desc, tipBelow: true),
            TourStep(target: .monthCards,  title: s.tourStep3Title, desc: s.tourStep3Desc, tipBelow: true),
        ]
    }

    var body: some View {
        let step = steps[stepIndex]
        let rawFrame: CGRect = anchors[step.target].map { proxy[$0] } ?? .zero
        let frame = clampedFrame(rawFrame, for: step.target)

        ZStack(alignment: .topLeading) {
            spotlightCanvas(frame: frame, target: step.target)
                .ignoresSafeArea()
                .onTapGesture { if !isNavigating { advance() } }

            if frame != .zero {
                let borderRadius: CGFloat = step.target == .tabBar ? 32 : 22
                RoundedRectangle(cornerRadius: borderRadius, style: .continuous)
                    .stroke(Theme.accent, lineWidth: 2)
                    .frame(width: frame.width + 10, height: frame.height + 10)
                    .shadow(color: Theme.accent.opacity(0.55), radius: 14)
                    .position(x: frame.midX, y: frame.midY)
                    .opacity(appeared ? 1 : 0)
            }

            if frame != .zero {
                calloutView(step: step, frame: frame)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.92,
                                 anchor: step.tipBelow ? .top : .bottom)
            }
        }
        .opacity(isNavigating ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: isNavigating)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appeared)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: stepIndex)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { appeared = true }
        }
    }

    // Limit highlight area so it never covers too much screen
    private func clampedFrame(_ frame: CGRect, for target: TourTarget) -> CGRect {
        guard frame != .zero else { return frame }
        return frame
    }

    // MARK: - Spotlight Canvas

    private func spotlightCanvas(frame: CGRect, target: TourTarget) -> some View {
        let spotRadius: CGFloat = target == .tabBar ? 32 : 22
        return Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.72)))
            if frame != .zero {
                ctx.blendMode = .clear
                ctx.fill(Path(roundedRect: frame.insetBy(dx: -6, dy: -6), cornerRadius: spotRadius), with: .color(.black))
            }
        }
    }

    // MARK: - Callout

    private func calloutView(step: TourStep, frame: CGRect) -> some View {
        let cardWidth: CGFloat = min(proxy.size.width - 48, 320)
        let cardX = proxy.size.width / 2 - cardWidth / 2
        let spacing: CGFloat = 14
        let safeBottom = proxy.size.height - 120  // leave room above tab bar

        // Auto-flip: prefer below, but switch to above if it won't fit
        let fitsBelow = frame.maxY + spacing + estimatedCardHeight < safeBottom
        let tipBelow = step.tipBelow ? fitsBelow : false

        let rawCardY: CGFloat = tipBelow
            ? frame.maxY + spacing
            : frame.minY - spacing - estimatedCardHeight

        // Clamp so callout always stays on screen
        let clampedCardY = max(56, min(safeBottom - estimatedCardHeight, rawCardY))

        return VStack(alignment: .leading, spacing: 0) {
            if tipBelow {
                arrowPointer.padding(.leading, 28)
                card(step: step)
            } else {
                card(step: step)
                arrowPointer
                    .rotationEffect(.degrees(180))
                    .padding(.leading, 28)
            }
        }
        .frame(width: cardWidth)
        .position(x: cardX + cardWidth / 2, y: clampedCardY + estimatedCardHeight / 2)
    }

    private var estimatedCardHeight: CGFloat { 170 }

    private func card(step: TourStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(step.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(stepIndex + 1) / \(steps.count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            Text(step.desc)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == stepIndex ? Theme.accent : Theme.surfaceHigh)
                            .frame(width: i == stepIndex ? 8 : 5, height: i == stepIndex ? 8 : 5)
                            .animation(.spring(response: 0.3), value: stepIndex)
                    }
                }
                Spacer()
                Button(action: advance) {
                    HStack(spacing: 5) {
                        Text(stepIndex < steps.count - 1 ? lm.s.onboardingNext : lm.s.tutorialDismiss)
                            .font(.system(size: 14, weight: .bold))
                        if stepIndex < steps.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.accentGradient, in: Capsule())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
        )
    }

    private var arrowPointer: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 10))
            p.addLine(to: CGPoint(x: 10, y: 0))
            p.addLine(to: CGPoint(x: 20, y: 10))
            p.closeSubpath()
        }
        .fill(Theme.surface)
        .frame(width: 20, height: 10)
    }

    // MARK: - Navigation

    private func advance() {
        // Step index 2 = yearCards → advancing to monthCards, navigate first
        if stepIndex == 2 {
            appeared = false
            isNavigating = true
            NotificationCenter.default.post(name: .tourNavigateToFirstYear, object: nil)
            // Wait for navigation slide animation to fully complete, then show step 4
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                stepIndex += 1
                isNavigating = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    appeared = true
                }
            }
            return
        }

        appeared = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if stepIndex < steps.count - 1 {
                stepIndex += 1
                appeared = true
            } else {
                onFinish()
            }
        }
    }
}
