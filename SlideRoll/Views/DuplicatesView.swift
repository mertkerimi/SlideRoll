import SwiftUI
import Photos

struct DuplicatesView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    @State private var remaining: [[String]] = []
    @State private var currentIndex = 0
    @State private var chosenID: String? = nil
    @State private var animating = false

    private var isTR: Bool { lm.selected == .turkish }

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
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                            )
                        Text(lm.s.dupTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(lm.s.close) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isFinished {
                        Text("\(currentIndex + 1)/\(remaining.count)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .onAppear {
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
            progressBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            hintBanner
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 20)

            if let group = current {
                photoGrid(ids: group)
                    .padding(.horizontal, 16)
                    .id(currentIndex)
            }

            Spacer()

            skipButton
                .padding(.bottom, 32)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.surfaceHigh)
                    .frame(height: 4)
                Capsule()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(
                        width: remaining.isEmpty ? 0 : geo.size.width * (Double(currentIndex) / Double(remaining.count)),
                        height: 4
                    )
                    .shadow(color: .yellow.opacity(0.4), radius: 4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentIndex)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Hint Banner

    private var hintBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.accent)
            Text(lm.s.dupHint)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Photo Grid

    private func photoGrid(ids: [String]) -> some View {
        let columns = ids.count == 2
            ? [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ids, id: \.self) { id in
                DupPhotoCell(
                    photoID: id,
                    isChosen: chosenID == id,
                    isTR: isTR,
                    onTap: { keepThis(id: id, from: ids) }
                )
                .environment(vm)
            }
        }
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button { advance() } label: {
            HStack(spacing: 6) {
                Text(lm.s.dupSkip)
                    .font(.system(size: 15, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.textTertiary)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.yellow.opacity(0.15), .orange.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .blur(radius: 1)
                Circle()
                    .stroke(LinearGradient(colors: [.yellow, .orange.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.green)
                    .shadow(color: Theme.green.opacity(0.3), radius: 12)
            }

            VStack(spacing: 8) {
                Text(lm.s.dupCompleted)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(lm.s.dupCompletedSub)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button(lm.s.close) { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Logic

    private func keepThis(id: String, from group: [String]) {
        guard !animating else { return }
        animating = true
        chosenID = id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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

    // MARK: - Background

    private var backgroundGlows: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.yellow.opacity(0.06), .orange.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 320)
                .blur(radius: 90)
                .offset(x: 120, y: -180)
            Circle()
                .fill(Theme.accent.opacity(0.07))
                .frame(width: 220)
                .blur(radius: 70)
                .offset(x: -80, y: 250)
        }
    }
}

// MARK: - Duplicate Photo Cell

struct DupPhotoCell: View {
    let photoID: String
    let isChosen: Bool
    let isTR: Bool
    let onTap: () -> Void

    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var image: UIImage?
    @State private var asset: PHAsset?

    private var dateLabel: String? {
        guard let date = asset?.creationDate else { return nil }
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy"
        return f.string(from: date)
    }

    private var sizeLabel: String? {
        guard let w = asset?.pixelWidth, let h = asset?.pixelHeight, w > 0 else { return nil }
        if w >= 1000 || h >= 1000 {
            return "\(w / 1000).\((w % 1000) / 100)K × \(h / 1000).\((h % 1000) / 100)K"
        }
        return "\(w) × \(h)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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
            .frame(height: 200)
            .clipped()

            // Bottom metadata gradient
            if image != nil {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(spacing: 2) {
                    if let date = dateLabel {
                        Text(date)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    if let size = sizeLabel {
                        Text(size)
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(.bottom, isChosen ? 36 : 10)

                if isChosen {
                    Text(isTR ? "Tut" : "Keep")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isChosen
                        ? LinearGradient(colors: [Theme.green, Theme.green.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Theme.border, Theme.border], startPoint: .top, endPoint: .bottom),
                    lineWidth: isChosen ? 2.5 : 1
                )
        )
        .shadow(color: isChosen ? Theme.green.opacity(0.25) : .black.opacity(0.08), radius: isChosen ? 12 : 4, y: 3)
        .scaleEffect(isChosen ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isChosen)
        .overlay(alignment: .topTrailing) {
            if isChosen {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.green)
                    .background(Circle().fill(.white).padding(3))
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onTapGesture { onTap() }
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 400, height: 400))
            asset = vm.asset(for: photoID)
        }
    }
}
