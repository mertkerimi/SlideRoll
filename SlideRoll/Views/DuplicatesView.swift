import SwiftUI
import Photos
import PhotosUI

// MARK: - Main View

struct DuplicatesView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    @State private var remaining: [[String]] = []
    @State private var currentIndex = 0
    @State private var toDelete: Set<String> = []

    private var isTR: Bool { lm.selected == .turkish }
    private var current: [String]? {
        guard currentIndex < remaining.count else { return nil }
        return remaining[currentIndex]
    }
    // Show spinner only while scan is running AND we have nothing to show yet
    private var isLoading: Bool { remaining.isEmpty && vm.statsLoading }
    // Finished only after scan is fully done AND all groups reviewed
    private var isFinished: Bool { !vm.statsLoading && currentIndex >= remaining.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                backgroundGlows

                if isLoading {
                    loadingView.transition(.opacity)
                } else if isFinished {
                    completedView.transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    mainContent.transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: remaining.count)
            .animation(.easeInOut(duration: 0.35), value: vm.statsLoading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
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
                    if !isFinished && !isLoading {
                        HStack(spacing: 6) {
                            if vm.statsLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(Theme.textTertiary)
                            }
                            if !remaining.isEmpty {
                                Text("\(currentIndex + 1)/\(remaining.count)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
            }
            .task {
                await vm.loadLibraryStats()
                // Already loaded (second open) — build remaining immediately
                appendNewGroups(from: vm.duplicateGroups)
            }
            .onChange(of: vm.duplicateGroups.count) { _, _ in
                appendNewGroups(from: vm.duplicateGroups)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.yellow)
                .scaleEffect(1.3)
            Text(isTR ? "Kopyalar taranıyor..." : "Scanning for duplicates...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // Shown when the user has caught up to every group found so far, but the
    // background scan hasn't finished — distinct from `loadingView`, which is
    // only for the very first moment before anything has been found at all.
    private var searchingMoreView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.yellow)
            Text(isTR ? "Diğer olası kopyalar aranıyor..." : "Searching for more possible duplicates...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            HStack(spacing: 8) {
                hintBanner
                if skippedGroupsCount > 0 {
                    skippedChip
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 16)

            if let group = current {
                ScrollView(showsIndicators: false) {
                    photoGrid(ids: group)
                        .padding(.horizontal, 16)
                        .id(currentIndex)
                }
            } else if vm.statsLoading {
                // Caught up to everything found so far, but the background
                // scan is still running — without this, a user who reviews
                // quickly hits a blank gap here until more groups stream in.
                searchingMoreView
            }

            Spacer(minLength: 0)

            actionArea
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceHigh).frame(height: 4)
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
            Text(isTR
                 ? "Silmek istediklerinize dokunun"
                 : "Tap photos to mark for deletion")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Skipped Chip

    private var skippedChip: some View {
        Button { resetSkipped() } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .semibold))
                Text(isTR ? "\(skippedGroupsCount) atlandı" : "\(skippedGroupsCount) skipped")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Grid (always 2 columns for readability)

    private func photoGrid(ids: [String]) -> some View {
        let displayed = Array(ids.prefix(8))
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(displayed, id: \.self) { id in
                DupPhotoCell(
                    photoID: id,
                    groupIDs: displayed,
                    isMarkedForDelete: toDelete.contains(id),
                    isTR: isTR,
                    onToggle: { toggleDelete(id) }
                )
                .environment(vm)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionArea: some View {
        HStack(spacing: 12) {
            Button { skipCurrentGroup() } label: {
                HStack(spacing: 6) {
                    Text(lm.s.dupSkip)
                        .font(.system(size: 15, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.textTertiary)
                .padding(.vertical, 13)
                .padding(.horizontal, 20)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
            }

            if !toDelete.isEmpty {
                Button { deleteSelected() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(isTR ? "\(toDelete.count) Fotoğrafı Sil" : "Delete \(toDelete.count)")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.85), in: Capsule())
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: toDelete.isEmpty)
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.yellow.opacity(0.15), .orange.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
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
            if skippedGroupsCount > 0 {
                Button { resetSkipped() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isTR
                             ? "\(skippedGroupsCount) grup atlandı — tekrar gözden geçir"
                             : "\(skippedGroupsCount) skipped — review again")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(Theme.accent.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Logic

    private func toggleDelete(_ id: String) {
        if toDelete.contains(id) { toDelete.remove(id) } else { toDelete.insert(id) }
    }

    private func deleteSelected() {
        guard let group = current else { return }
        for id in toDelete { vm.applyDecisionGlobal(.delete, to: id) }
        for id in group where !toDelete.contains(id) { vm.applyDecisionGlobal(.keep, to: id) }
        toDelete = []
        advance()
    }

    // "Bu grubu atla" — persists the skip so it doesn't resurface next session.
    private func skipCurrentGroup() {
        if let group = current {
            var keys = vm.skippedDuplicateGroupKeys
            keys.insert(group.sorted().joined(separator: ","))
            vm.skippedDuplicateGroupKeys = keys
        }
        advance()
    }

    private func advance() {
        toDelete = []
        withAnimation(.easeInOut(duration: 0.3)) { currentIndex += 1 }
    }

    // Appends only genuinely new groups (not already in remaining, not skipped)
    private func appendNewGroups(from allGroups: [[String]]) {
        let decidedIDs = Set(vm.monthGroups.flatMap { g in
            g.decisions.compactMap { id, d in d != .undecided ? id : nil }
        })
        let skippedKeys = vm.skippedDuplicateGroupKeys
        let existingKeys = Set(remaining.map { $0.sorted().joined(separator: ",") })
        let newOnes = allGroups.compactMap { group -> [String]? in
            let undecided = group.filter { !decidedIDs.contains($0) }
            guard undecided.count >= 2 else { return nil }
            let key = undecided.sorted().joined(separator: ",")
            return (existingKeys.contains(key) || skippedKeys.contains(key)) ? nil : undecided
        }
        if !newOnes.isEmpty { remaining.append(contentsOf: newOnes) }
    }

    // Currently-skipped groups that are still valid possible-duplicate groups
    // (i.e. haven't since been fully decided elsewhere in the app).
    private var skippedGroupsCount: Int {
        let keys = vm.skippedDuplicateGroupKeys
        guard !keys.isEmpty else { return 0 }
        let decidedIDs = Set(vm.monthGroups.flatMap { g in
            g.decisions.compactMap { id, d in d != .undecided ? id : nil }
        })
        return vm.duplicateGroups.reduce(into: 0) { count, group in
            let undecided = group.filter { !decidedIDs.contains($0) }
            guard undecided.count >= 2 else { return }
            if keys.contains(undecided.sorted().joined(separator: ",")) { count += 1 }
        }
    }

    // Un-skips every currently-skipped group and queues them back up for review.
    private func resetSkipped() {
        let keys = vm.skippedDuplicateGroupKeys
        guard !keys.isEmpty else { return }
        vm.skippedDuplicateGroupKeys = []

        // Skipped groups were never removed from `remaining` — currentIndex
        // just moved past them — so blindly appending "restored" copies would
        // duplicate them (and inflate the total count, e.g. 250 -> 500).
        // Strip out their old entries first, adjusting currentIndex for
        // whatever was removed ahead of it, before adding fresh copies back.
        var removedBeforeCurrent = 0
        var trimmed: [[String]] = []
        for (i, group) in remaining.enumerated() {
            if keys.contains(group.sorted().joined(separator: ",")) {
                if i < currentIndex { removedBeforeCurrent += 1 }
            } else {
                trimmed.append(group)
            }
        }
        currentIndex -= removedBeforeCurrent
        remaining = trimmed

        let decidedIDs = Set(vm.monthGroups.flatMap { g in
            g.decisions.compactMap { id, d in d != .undecided ? id : nil }
        })
        let restored = vm.duplicateGroups.compactMap { group -> [String]? in
            let undecided = group.filter { !decidedIDs.contains($0) }
            guard undecided.count >= 2 else { return nil }
            return keys.contains(undecided.sorted().joined(separator: ",")) ? undecided : nil
        }
        remaining.append(contentsOf: restored)
    }

    // MARK: - Background

    private var backgroundGlows: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.yellow.opacity(0.06), .orange.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 320).blur(radius: 90).offset(x: 120, y: -180)
            Circle()
                .fill(Theme.accent.opacity(0.07))
                .frame(width: 220).blur(radius: 70).offset(x: -80, y: 250)
        }
    }
}

// MARK: - Duplicate Photo Cell

struct DupPhotoCell: View {
    let photoID: String
    let groupIDs: [String]
    let isMarkedForDelete: Bool
    let isTR: Bool
    let onToggle: () -> Void

    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var image: UIImage?
    @State private var asset: PHAsset?
    @State private var fileMB: Double?
    @State private var showFullscreen = false

    var body: some View {
        // A `.frame(height:)`-only Image with `.aspectRatio(.fill)` computes its
        // OWN ideal width from the source photo's aspect ratio (240 * ratio) and
        // reports that upward — for a landscape photo that's wider than the
        // grid column, so it renders past the column into the next one.
        // `.frame(maxWidth: .infinity)` doesn't fix this (it's only a ceiling,
        // not a target), so read the column's *actual* width via GeometryReader
        // and pin the image to that exact size before clipping.
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Photo
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Theme.surface
                            .overlay(ProgressView().tint(Theme.accent).scaleEffect(0.7))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                // Delete overlay
                if isMarkedForDelete {
                    Color.red.opacity(0.35)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }

                // Bottom metadata bar (only when not marked)
                if image != nil && !isMarkedForDelete {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.65)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    VStack(spacing: 2) {
                        if let date = dateLabel {
                            Text(date)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        if let mb = fileMB {
                            Text(String(format: "%.1f MB", mb))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isMarkedForDelete ? Color.red.opacity(0.85) : Theme.border,
                        lineWidth: isMarkedForDelete ? 2.5 : 1
                    )
            )
            // Live photo badge — top left
            .overlay(alignment: .topLeading) {
                if asset?.mediaSubtypes.contains(.photoLive) == true {
                    Image(systemName: "livephoto")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(8)
                }
            }
            // Fullscreen expand button — top right
            .overlay(alignment: .topTrailing) {
                if image != nil {
                    Button { showFullscreen = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .padding(8)
                }
            }
            .scaleEffect(isMarkedForDelete ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isMarkedForDelete)
            .onTapGesture { onToggle() }
        }
        .frame(height: 240)
        .sheet(isPresented: $showFullscreen) {
            FullscreenPhotoView(
                groupIDs: groupIDs,
                startIndex: groupIDs.firstIndex(of: photoID) ?? 0
            )
            .environment(vm)
        }
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 600, height: 700))
            asset = vm.asset(for: photoID)
            if let a = asset {
                let bytes: Int64 = await Task.detached {
                    PHAssetResource.assetResources(for: a)
                        .reduce(0) { PhotoLibraryViewModel.resourceBytes($1) + $0 }
                }.value
                if bytes > 0 { fileMB = Double(bytes) / 1_000_000 }
            }
        }
    }

    private var dateLabel: String? {
        guard let date = asset?.creationDate else { return nil }
        let f = DateFormatter(); f.dateFormat = "dd.MM.yy"; return f.string(from: date)
    }
}

// MARK: - Fullscreen Photo Sheet (swipeable)

struct FullscreenPhotoView: View {
    let groupIDs: [String]
    let startIndex: Int
    @Environment(\.dismiss) var dismiss
    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var currentIndex: Int

    init(groupIDs: [String], startIndex: Int) {
        self.groupIDs = groupIDs
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(groupIDs.enumerated()), id: \.offset) { index, id in
                    FullscreenPageView(photoID: id)
                        .tag(index)
                        .environment(vm)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .ignoresSafeArea()

            // Header bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.85))
                        .background(Color.black.opacity(0.35), in: Circle())
                }
                Spacer()
                Text("\(currentIndex + 1) / \(groupIDs.count)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
    }
}

// MARK: - Single page inside fullscreen

struct FullscreenPageView: View {
    let photoID: String
    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var stage: PageStage = .loading
    @State private var image: UIImage?
    @State private var livePhoto: PHLivePhoto?

    private enum PageStage { case loading, photo, livePhoto }

    private var isLive: Bool { stage == .livePhoto }

    var body: some View {
        ZStack {
            Color.black
            switch stage {
            case .loading:
                ProgressView().tint(.white).scaleEffect(1.2)
            case .photo:
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            case .livePhoto:
                if let lp = livePhoto {
                    LivePhotoView(livePhoto: lp)
                } else if let img = image {
                    // Thumbnail shown while live photo loads
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if isLive {
                HStack(spacing: 5) {
                    Image(systemName: "livephoto")
                        .font(.system(size: 13, weight: .semibold))
                    Text("LIVE")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(.leading, 16)
                .padding(.top, 16)
            }
        }
        .overlay(alignment: .bottom) {
            if isLive && livePhoto != nil {
                Text("Oynatmak için basılı tut")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 40)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let asset = vm.asset(for: photoID) else { stage = .photo; return }
        if asset.mediaSubtypes.contains(.photoLive) {
            // Show thumbnail immediately, then load live photo
            image = await vm.loadThumbnail(for: photoID)
            stage = .livePhoto
            livePhoto = await vm.loadLivePhoto(for: photoID, targetSize: CGSize(width: 1080, height: 1440))
        } else {
            image = await vm.loadThumbnail(for: photoID)
            stage = .photo
            if let full = await vm.loadImage(for: photoID, targetSize: CGSize(width: 1200, height: 1600)) {
                image = full
            }
        }
    }
}

// MARK: - PHLivePhotoView wrapper

struct LivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
        // Brief hint animation so user knows it's a Live Photo
        uiView.startPlayback(with: .hint)
    }
}
