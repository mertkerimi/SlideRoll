import SwiftUI

struct DuplicatesView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    // groups remaining to decide
    @State private var remaining: [[String]] = []
    @State private var currentIndex = 0
    @State private var chosenID: String? = nil
    @State private var animating = false

    private var current: [String]? {
        guard currentIndex < remaining.count else { return nil }
        return remaining[currentIndex]
    }

    private var isFinished: Bool { remaining.isEmpty || currentIndex >= remaining.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                backgroundGlows

                if isFinished {
                    completedView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    mainContent
                }
            }
            .animation(.easeInOut(duration: 0.35), value: isFinished)
            .animation(.easeInOut(duration: 0.25), value: currentIndex)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(lm.s.dupTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(currentIndex + 1) / \(remaining.count)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(lm.s.close) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .onAppear {
                // Only show groups where ALL photos are still undecided
                let decidedIDs = Set(
                    vm.monthGroups.flatMap { group in
                        group.decisions.compactMap { id, decision in
                            decision != .undecided ? id : nil
                        }
                    }
                )
                remaining = vm.duplicateGroups.compactMap { group in
                    let undecided = group.filter { !decidedIDs.contains($0) }
                    return undecided.count >= 2 ? undecided : nil
                }
            }
        }
    }

    // MARK: - Main

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHigh).frame(height: 3)
                    Capsule().fill(Theme.accentGradient)
                        .frame(width: geo.size.width * (remaining.isEmpty ? 0 : Double(currentIndex) / Double(remaining.count)), height: 3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentIndex)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Hint
            Text(lm.s.dupHint)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Photo grid
            if let group = current {
                photoGrid(ids: group)
                    .padding(.horizontal, 16)
                    .id(currentIndex)
            }

            Spacer()

            // Skip button
            Button {
                advance()
            } label: {
                Text(lm.s.dupSkip)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 12)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Photo Grid

    private func photoGrid(ids: [String]) -> some View {
        let columns = ids.count == 2
            ? [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            : [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(ids, id: \.self) { id in
                DupPhotoCell(
                    photoID: id,
                    isChosen: chosenID == id,
                    onTap: { keepThis(id: id, from: ids) }
                )
                .environment(vm)
            }
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Theme.green.opacity(0.12)).frame(width: 110, height: 110)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.green)
            }
            VStack(spacing: 8) {
                Text(lm.s.dupCompleted)
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Text(lm.s.dupCompletedSub)
                    .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button(lm.s.close) { dismiss() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Logic

    private func keepThis(id: String, from group: [String]) {
        guard !animating else { return }
        animating = true
        chosenID = id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // keep chosen, delete rest
            for photoID in group where photoID != id {
                vm.applyDecisionGlobal(.delete, to: photoID)
            }
            vm.applyDecisionGlobal(.keep, to: id)
            chosenID = nil
            animating = false
            advance()
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentIndex += 1
        }
    }

    private var backgroundGlows: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.08)).frame(width: 260).blur(radius: 70).offset(x: 100, y: -200)
        }
    }
}

// MARK: - Duplicate Photo Cell

struct DupPhotoCell: View {
    let photoID: String
    let isChosen: Bool
    let onTap: () -> Void

    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Theme.surface
                        .overlay(ProgressView().tint(Theme.accent).scaleEffect(0.8))
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isChosen ? Theme.green : Theme.border, lineWidth: isChosen ? 2.5 : 1)
            )
            .scaleEffect(isChosen ? 1.03 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isChosen)

            if isChosen {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.green)
                    .background(Circle().fill(.white).padding(3))
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onTapGesture { onTap() }
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 400, height: 400))
        }
    }
}
