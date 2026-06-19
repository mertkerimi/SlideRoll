import SwiftUI
import Photos

struct GlobalReviewView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(AdManager.self) var adManager
    @Environment(\.dismiss) var dismiss

    @State private var pendingIDs: [String] = []
    @State private var currentIndex: Int = 0
    @State private var decisionHistory: [(id: String, decision: PhotoDecision)] = []
    @State private var sessionDecisions: [String: PhotoDecision] = [:]
    @State private var cardID = UUID()
    @State private var cardFlyout: SwipeDirection? = nil
    @State private var showTrash = false
    @State private var swipeCount = 0

    private var isFinished: Bool { pendingIDs.isEmpty || currentIndex >= pendingIDs.count }
    private var keepCount: Int   { sessionDecisions.values.filter { $0 == .keep }.count }
    private var deleteCount: Int { vm.toDeleteIDs.count }
    private var skipCount: Int   { sessionDecisions.values.filter { $0 == .skip }.count }

    private var currentPhotoDate: String? {
        guard !isFinished, currentIndex < pendingIDs.count else { return nil }
        guard let date = vm.asset(for: pendingIDs[currentIndex])?.creationDate else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMMM yyyy"
        fmt.locale = Locale(identifier: lm.selected == .turkish ? "tr_TR" : lm.selected == .german ? "de_DE" : "en_US")
        return fmt.string(from: date)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            backgroundGlows

            if isFinished {
                completedView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity))
            } else {
                reviewContent
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isFinished)
        .sheet(isPresented: $showTrash) {
            TrashView().environment(vm).environment(lm)
        }
        .onAppear {
            pendingIDs = vm.allPendingIDs
            vm.startCaching(ids: Array(pendingIDs.prefix(10)), targetSize: CGSize(width: 700, height: 900))
        }
    }

    // MARK: - Background

    private var backgroundGlows: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.10)).frame(width: 280).blur(radius: 70).offset(x: 120, y: -250)
            Circle().fill(Theme.green.opacity(0.07)).frame(width: 200).blur(radius: 50).offset(x: -100, y: 200)
        }
    }

    // MARK: - Review Content

    private var reviewContent: some View {
        VStack(spacing: 0) {
            navBar.padding(.top, 24)
            progressStrip.padding(.horizontal, 24).padding(.top, 20)
            cardDeck.padding(.horizontal, 20).padding(.top, 20)
            statsAndDock.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 28)
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        ZStack {
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text(lm.s.shuffleTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text("\((currentIndex + 1).fmtCount) / \(pendingIDs.count.fmtCount)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                if let dateStr = currentPhotoDate {
                    Text(dateStr)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .transition(.opacity)
                }
            }
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Theme.surface, in: Circle())
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Progress Strip

    private var progressStrip: some View {
        let progress = pendingIDs.isEmpty ? 0.0 : Double(currentIndex) / Double(pendingIDs.count)
        return VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHigh).frame(height: 4)
                    Capsule()
                        .fill(Theme.accentGradient)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 4)
            HStack {
                Text(lm.s.percentCompleted(progress * 100))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("\(currentIndex.fmtCount) / \(pendingIDs.count.fmtCount)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: - Card Deck

    private var cardDeck: some View {
        ZStack {
            if currentIndex + 2 < pendingIDs.count {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Theme.surfaceHigh).scaleEffect(0.87).offset(y: 22)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            }
            if currentIndex + 1 < pendingIDs.count {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Theme.surface).scaleEffect(0.93).offset(y: 11)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
            }
            PhotoCardView(
                photoID: pendingIDs[currentIndex],
                onSwipe: { dir in cardFlyout = nil; handleSwipe(dir) },
                onTapUndo: { undoLast() },
                externalFlyout: $cardFlyout
            )
            .id(cardID)
            .environment(vm)
            .environment(lm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stats + Dock

    private var statsAndDock: some View {
        let s = lm.s
        return VStack(spacing: 10) {
            HStack(spacing: 0) {
                counterCell(count: keepCount, label: s.keptCounter, color: Theme.green)
                counterDivider
                counterCell(count: deleteCount, label: s.toDeleteCounter, color: Theme.red)
                counterDivider
                counterCell(count: skipCount, label: s.skippedCounter, color: Theme.orange)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
            )

            HStack(spacing: 10) {
                // Skip — leftmost
                actionButton(icon: "clock", color: Theme.orange, bg: Theme.orange.opacity(0.15), border: false) {
                    cardFlyout = .skip
                }

                // Delete — equal center
                Button { cardFlyout = .delete } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "xmark").font(.system(size: 18, weight: .bold))
                        Text(lm.s.deleteBadge).font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .background(Theme.redGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Theme.red.opacity(0.35), radius: 14, y: 6)
                }

                // Keep — equal center
                Button { cardFlyout = .keep } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "checkmark").font(.system(size: 18, weight: .bold))
                        Text(lm.s.keepBadge).font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .background(Theme.greenGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Theme.green.opacity(0.4), radius: 14, y: 6)
                }

                // Trash — rightmost, with badge
                ZStack(alignment: .topTrailing) {
                    actionButton(icon: "trash", color: Theme.textSecondary, bg: Theme.surface, border: true) {
                        showTrash = true
                    }
                    if !vm.toDeleteIDs.isEmpty {
                        Text("\(vm.toDeleteIDs.count)")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, vm.toDeleteIDs.count >= 10 ? 5 : 3)
                            .padding(.vertical, 3)
                            .background(Theme.red, in: Capsule())
                            .offset(x: vm.toDeleteIDs.count >= 10 ? 8 : 4, y: -4)
                    }
                }
            }
        }
    }

    private var counterDivider: some View {
        Rectangle().fill(Theme.border).frame(width: 1, height: 22)
    }

    private func counterCell(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text("\(count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(count > 0 ? color : Theme.textTertiary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(icon: String, color: Color, bg: Color, border: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
                .frame(width: 54, height: 60)
                .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(border ? RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1) : nil)
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        let s = lm.s
        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(Theme.green.opacity(0.12)).frame(width: 110, height: 110)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.green)
                }
                VStack(spacing: 10) {
                    Text(s.shuffleCompleted)
                        .font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text(s.photosReviewedCount(currentIndex))
                        .font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 0) {
                    counterCell(count: keepCount, label: s.keptDone, color: Theme.green)
                    counterDivider
                    counterCell(count: deleteCount, label: s.toDeleteStat, color: Theme.red)
                    counterDivider
                    counterCell(count: skipCount, label: s.skippedDone, color: Theme.orange)
                }
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
                )
                .padding(.horizontal, 24)
            }
            Spacer()
            VStack(spacing: 12) {
                if !vm.toDeleteIDs.isEmpty {
                    Button { showTrash = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash.fill")
                            Text(s.permanentlyDelete(vm.toDeleteIDs.count)).font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(Theme.redGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Theme.red.opacity(0.4), radius: 16, y: 8)
                    }
                }
                Button(s.close) { dismiss() }
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.textSecondary).padding(.vertical, 12)
            }
            .padding(.horizontal, 28).padding(.bottom, 40)
        }
    }

    // MARK: - Logic

    private func handleSwipe(_ direction: SwipeDirection) {
        guard currentIndex < pendingIDs.count else { return }
        let photoID = pendingIDs[currentIndex]
        let decision: PhotoDecision
        switch direction {
        case .keep:   decision = .keep
        case .delete: decision = .delete
        case .skip:   decision = .skip
        case .none:   return
        }
        vm.applyDecisionGlobal(decision, to: photoID)
        sessionDecisions[photoID] = decision
        decisionHistory.append((id: photoID, decision: decision))
        vm.startCaching(ids: Array(pendingIDs.dropFirst(currentIndex + 1).prefix(8)),
                        targetSize: CGSize(width: 700, height: 900))
        let nextIndex = currentIndex + 1
        withAnimation(.easeInOut(duration: 0.1)) { currentIndex = nextIndex }
        cardID = UUID()
        swipeCount += 1
        // Offer an ad at a natural break — every 15 decisions or when the shuffle
        // session is finished. AdManager enforces the launch grace + cooldown.
        if swipeCount % 15 == 0 || nextIndex >= pendingIDs.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                adManager.maybeShow()
            }
        }
    }

    private func undoLast() {
        guard !decisionHistory.isEmpty, currentIndex > 0 else { return }
        let last = decisionHistory.removeLast()
        vm.undoDecisionGlobal(for: last.id)
        sessionDecisions.removeValue(forKey: last.id)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentIndex -= 1
        }
        cardID = UUID()
    }
}
