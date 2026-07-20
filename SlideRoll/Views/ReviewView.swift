import SwiftUI

struct ReviewView: View {
    let group: MonthGroup
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(AdManager.self) var adManager
    @Environment(SubscriptionManager.self) var subManager
    @Environment(\.dismiss) var dismiss

    @State private var pendingIDs: [String] = []
    @State private var currentIndex: Int = 0
    @State private var decisionHistory: [(id: String, decision: PhotoDecision)] = []
    @State private var cardID = UUID()
    @State private var showTrash = false
    @State private var showPaywall = false
    @State private var showBrowse = false
    @State private var cardFlyout: SwipeDirection? = nil
    @State private var swipeCount = 0
    @State private var groupTotalBytes: Int64 = 0
    @State private var cachedDeletedBytes: Int64 = 0

    @AppStorage("hasSeenReviewTutorial") private var hasSeenReviewTutorial = false
    @State private var showTutorial = false

    private var currentGroup: MonthGroup? {
        vm.monthGroups.first(where: { $0.id == group.id })
    }
    private var isFinished: Bool { pendingIDs.isEmpty || currentIndex >= pendingIDs.count }
    private var keepCount: Int   { currentGroup?.decisions.values.filter { $0 == .keep }.count ?? 0 }
    private var deleteCount: Int { currentGroup?.decisions.values.filter { $0 == .delete }.count ?? 0 }
    private var skipCount: Int   { currentGroup?.decisions.values.filter { $0 == .skip }.count ?? 0 }

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
        .sheet(isPresented: $showBrowse) {
            MonthBrowseView(group: group).environment(vm).environment(lm)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environment(subManager).environment(lm)
        }
        .onAppear {
            // Presenting an interstitial ad from within this sheet makes SwiftUI
            // treat the sheet as having disappeared and reappeared, re-firing
            // onAppear. Only run first-time setup, or an in-progress review's
            // currentIndex/decisionHistory get silently wiped mid-session.
            if pendingIDs.isEmpty {
                setupPending()
            }
            if !hasSeenReviewTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showTutorial = true
                }
            }
        }
        .task {
            groupTotalBytes = await vm.totalBytes(in: group.id)
        }
        .overlay {
            if showTutorial {
                ReviewTutorialOverlay(onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) { showTutorial = false }
                    hasSeenReviewTutorial = true
                })
                .environment(lm)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showTutorial)
    }

    private var backgroundGlows: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.10))
                .frame(width: 280).blur(radius: 70)
                .offset(x: 120, y: -250)
            Circle()
                .fill(Theme.green.opacity(0.07))
                .frame(width: 200).blur(radius: 50)
                .offset(x: -100, y: 200)
        }
    }

    private var reviewContent: some View {
        VStack(spacing: 0) {
            navBar.padding(.top, 24)
            progressStrip.padding(.horizontal, 24).padding(.top, 20)
            cardDeck.padding(.horizontal, 20).padding(.top, 20)
            statsAndDock.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 28)
        }
    }

    private var navBar: some View {
        ZStack {
            VStack(spacing: 3) {
                Text(lm.s.monthTitle(from: group.id))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("\((currentIndex + 1).fmtCount) / \(pendingIDs.count.fmtCount)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
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
                .accessibilityLabel(lm.s.close)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }

    private var progressStrip: some View {
        let deletedBytes = cachedDeletedBytes
        let savings = groupTotalBytes > 0 ? Double(deletedBytes) / Double(groupTotalBytes) : 0

        return VStack(spacing: 6) {
            // Review progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHigh).frame(height: 4)
                    Capsule()
                        .fill(Theme.accentGradient)
                        .frame(width: geo.size.width * (currentGroup?.progress ?? 0), height: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentGroup?.progress)
                }
            }
            .frame(height: 4)

            HStack {
                Text(lm.s.percentCompleted((currentGroup?.progress ?? 0) * 100))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("\((currentGroup?.reviewed ?? 0).fmtCount) / \((currentGroup?.total ?? 0).fmtCount)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            // Storage savings bar — shown only when we have size data
            if groupTotalBytes > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surfaceHigh).frame(height: 3)
                        Capsule()
                            .fill(Theme.greenGradient)
                            .frame(width: geo.size.width * savings, height: 3)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: savings)
                    }
                }
                .frame(height: 3)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.green)
                        Text(lm.s.savingsLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                    Text(deletedBytes > 0 ? formatBytes(deletedBytes) : "—")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(deletedBytes > 0 ? Theme.green : Theme.textTertiary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: deletedBytes)
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }

    private var cardDeck: some View {
        ZStack {
            if currentIndex + 2 < pendingIDs.count {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Theme.surfaceHigh)
                    .scaleEffect(0.87).offset(y: 22)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            }
            if currentIndex + 1 < pendingIDs.count {
                NextCardPreview(photoID: pendingIDs[currentIndex + 1])
                    .id(pendingIDs[currentIndex + 1])
                    .environment(vm)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .scaleEffect(0.93)
                    .offset(y: 11)
                    .blur(radius: 7)
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
                    .allowsHitTesting(false)
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

    private var statsAndDock: some View {
        let s = lm.s
        return VStack(spacing: 10) {
            // Compact counter row
            HStack(spacing: 0) {
                counterCell(count: keepCount, label: s.keptCounter, color: Theme.green)
                counterDivider
                counterCell(count: deleteCount, label: s.toDeleteCounter, color: Theme.red)
                counterDivider
                counterCell(count: skipCount, label: s.skippedCounter, color: Theme.orange)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border, lineWidth: 1))
            )

            HStack(spacing: 10) {
                // Skip — leftmost
                actionButton(icon: "clock", color: Theme.orange,
                             bg: Theme.orange.opacity(0.15), border: false, a11y: s.laterBadge) {
                    cardFlyout = .skip
                }

                // Delete — equal center
                Button { cardFlyout = .delete } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                        Text(s.deleteBadge)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Theme.redGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Theme.red.opacity(0.35), radius: 14, y: 6)
                }
                .accessibilityLabel(s.deleteBadge)

                // Keep — equal center
                Button { cardFlyout = .keep } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                        Text(s.keepBadge)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Theme.greenGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Theme.green.opacity(0.4), radius: 14, y: 6)
                }
                .accessibilityLabel(s.keepBadge)

                // Trash — rightmost
                ZStack(alignment: .topTrailing) {
                    actionButton(icon: "trash", color: Theme.textSecondary,
                                 bg: Theme.surface, border: true, a11y: s.a11yTrash) {
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
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(icon: String, color: Color, bg: Color, border: Bool, a11y: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 54, height: 60)
                .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    border ? RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1) : nil
                )
        }
        .accessibilityLabel(a11y)
    }

    private var completedView: some View {
        let s = lm.s
        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(Theme.green.opacity(0.12)).frame(width: 110, height: 110)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.green)
                }
                VStack(spacing: 10) {
                    Text(s.monthCompleted)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(s.photosReviewedCount(currentGroup?.reviewed ?? 0))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
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
                            Text(s.permanentlyDelete(vm.toDeleteIDs.count))
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Theme.redGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Theme.red.opacity(0.4), radius: 16, y: 8)
                    }
                }
                HStack(spacing: 10) {
                    Button { showBrowse = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 14, weight: .semibold))
                            Text(s.browsePhotos)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.accent.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.accent.opacity(0.25), lineWidth: 1))
                        )
                    }

                    Button {
                        vm.resetGroupDecisions(groupID: group.id)
                        setupPending()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text(s.restartReview)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Theme.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.orange.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.orange.opacity(0.25), lineWidth: 1))
                        )
                    }
                }
                Button(s.close) { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func setupPending() {
        guard let g = currentGroup else { return }
        pendingIDs = g.pendingIDs
        currentIndex = 0
        vm.startCaching(ids: Array(pendingIDs.prefix(10)), targetSize: CGSize(width: 700, height: 900))
    }

    private func handleSwipe(_ direction: SwipeDirection) {
        guard currentIndex < pendingIDs.count else { return }
        if direction != .skip && subManager.hasReachedDailyLimit {
            showPaywall = true; return
        }
        let photoID = pendingIDs[currentIndex]
        let decision: PhotoDecision
        switch direction {
        case .keep:   decision = .keep
        case .delete: decision = .delete
        case .skip:   decision = .skip
        case .none:   return
        }
        vm.applyDecision(decision, to: photoID, in: group.id)
        if decision != .skip { subManager.recordSwipe() }
        decisionHistory.append((id: photoID, decision: decision))
        vm.startCaching(ids: Array(pendingIDs.dropFirst(currentIndex + 1).prefix(8)),
                        targetSize: CGSize(width: 700, height: 900))
        let nextIndex = currentIndex + 1
        withAnimation(.easeInOut(duration: 0.1)) { currentIndex = nextIndex }
        cardID = UUID()
        refreshDeletedBytes()
        swipeCount += 1
        let totalPhotos = pendingIDs.count
        let isFinishedNow = nextIndex >= totalPhotos

        if swipeCount % 20 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                adManager.show()
            }
        } else if isFinishedNow && totalPhotos >= 30 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                adManager.show()
            }
        }
    }

    private func undoLast() {
        guard !decisionHistory.isEmpty, currentIndex > 0 else { return }
        let last = decisionHistory.removeLast()
        vm.undoDecision(for: last.id, in: group.id)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentIndex -= 1
        }
        cardID = UUID()
        refreshDeletedBytes()
    }

    private func refreshDeletedBytes() {
        let groupID = group.id
        Task.detached(priority: .utility) {
            let bytes = await vm.toDeleteBytes(in: groupID)
            await MainActor.run { cachedDeletedBytes = bytes }
        }
    }
}

// MARK: - Next Card Preview (blurred background)

private struct NextCardPreview: View {
    let photoID: String
    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 400, height: 520))
        }
    }
}
