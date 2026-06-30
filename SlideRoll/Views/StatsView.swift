import SwiftUI

struct StatsView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(SubscriptionManager.self) var subManager

    @State private var selectedLargest: IdentifiablePhoto? = nil
    @State private var showDuplicates = false
    @State private var showPaywall = false
    @State private var mediaTab = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            backgroundGlows
            content
        }
        .sheet(isPresented: $showDuplicates) {
            DuplicatesView().environment(vm).environment(lm)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView().environment(subManager).environment(lm)
        }
        .sheet(item: $selectedLargest) { photo in
            LargestPhotoDetailView(photoID: photo.id, bytes: photo.bytes, date: photo.date, isVideo: photo.isVideo)
                .environment(vm).environment(lm)
        }
        .task { await vm.loadLibraryStats() }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                duplicateFinderCard

                summaryCard

                // Media count cards — appear instantly (Phase 1)
                HStack(spacing: 12) {
                    mediaCard(icon: "photo.fill", iconColor: Theme.accent,
                              title: lm.s.statPhotos, count: vm.photoCount, bytes: vm.photoBytes)
                    mediaCard(icon: "video.fill", iconColor: Theme.orange,
                              title: lm.s.statVideos, count: vm.videoCount, bytes: vm.videoBytes)
                }

                // Largest section — appears as soon as first 200 assets scanned
                if !vm.largestPhotos.isEmpty || !vm.largestVideos.isEmpty {
                    largestMediaCard
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Year chart — appears when stats computation finishes
                if !vm.statsLoading {
                    if !vm.yearlyStorage.isEmpty {
                        yearChartCard
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.accent).scaleEffect(0.75)
                        Text(lm.s.statCalculating)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: vm.statsLoading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Largest Media Card (tabbed)

    private var largestMediaCard: some View {
        VStack(spacing: 12) {
            // Tab picker
            HStack(spacing: 0) {
                tabButton(title: lm.s.statLargestPhotos, index: 0)
                tabButton(title: lm.s.statLargestVideos, index: 1)
            }
            .padding(4)
            .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Rows
            if mediaTab == 0 {
                if vm.largestPhotos.isEmpty {
                    emptyLabel
                } else {
                    VStack(spacing: 8) {
                        ForEach(vm.largestPhotos, id: \.id) { item in
                            let photo = IdentifiablePhoto(id: item.id, bytes: item.bytes, date: item.date)
                            Button { selectedLargest = photo } label: {
                                LargestPhotoRow(photoID: item.id, bytes: item.bytes, date: item.date)
                                    .environment(vm).environment(lm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                if vm.largestVideos.isEmpty {
                    emptyLabel
                } else {
                    VStack(spacing: 8) {
                        ForEach(vm.largestVideos, id: \.id) { item in
                            let media = IdentifiablePhoto(id: item.id, bytes: item.bytes, date: item.date, isVideo: true)
                            Button { selectedLargest = media } label: {
                                LargestPhotoRow(photoID: item.id, bytes: item.bytes, date: item.date,
                                                isVideo: true, duration: item.duration)
                                    .environment(vm).environment(lm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
    }

    private func tabButton(title: String, index: Int) -> some View {
        let selected = mediaTab == index
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { mediaTab = index }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    selected
                        ? AnyView(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface))
                        : AnyView(Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyLabel: some View {
        Text("—")
            .font(.system(size: 13))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }

    // MARK: - Media Card (half width)

    private func mediaCard(icon: String, iconColor: Color, title: String, count: Int, bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(bytes > 0 ? formatBytes(bytes) : "—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: bytes)
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary)
                Text(count > 0 ? lm.s.statItemCount(count) : "—")
                    .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: count)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
    }


    // MARK: - Year Chart

    private var yearChartCard: some View {
        let maxBytes = vm.yearlyStorage.map(\.bytes).max() ?? 1
        return VStack(alignment: .leading, spacing: 14) {
            Text(lm.s.statByYear)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 10) {
                ForEach(vm.yearlyStorage.prefix(8), id: \.year) { item in
                    HStack(spacing: 10) {
                        Text(item.year)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 36, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.surfaceHigh)
                                    .frame(height: 20)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.accentGradient)
                                    .frame(width: geo.size.width * CGFloat(item.bytes) / CGFloat(maxBytes), height: 20)
                            }
                        }
                        .frame(height: 20)

                        Text(formatBytes(item.bytes))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
    }

    // MARK: - Duplicate Finder Card

    private var duplicateFinderCard: some View {
        let isTR = lm.selected == .turkish
        return Button {
            if subManager.isPremium { showDuplicates = true }
            else { showPaywall = true }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.accentGradient)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(lm.s.dupTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(isTR ? "Benzer fotoğrafları bul ve temizle" : "Find and remove similar photos")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if subManager.isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                            )
                        Text("Premium")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.yellow.opacity(0.18), .orange.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(colors: [.yellow, .orange.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 8, x: 0, y: 2)
                    .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 1)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                        Text("Premium")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.textTertiary.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Theme.textTertiary.opacity(0.2), lineWidth: 1))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                subManager.isPremium
                                    ? LinearGradient(colors: [.yellow.opacity(0.45), .orange.opacity(0.2), .yellow.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Theme.border, Theme.border], startPoint: .top, endPoint: .bottom),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: subManager.isPremium ? .yellow.opacity(0.1) : .clear, radius: 12, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - SlideRoll Card

    private var summaryCard: some View {
        let totalReviewed = vm.monthGroups.reduce(0) { $0 + $1.reviewed }
        let totalPhotos   = vm.monthGroups.reduce(0) { $0 + $1.total }
        let toDelete      = vm.toDeleteIDs.count
        let kept          = vm.monthGroups.reduce(0) { $0 + $1.decisions.values.filter { $0 == .keep }.count }
        let progress      = totalPhotos > 0 ? Double(totalReviewed) / Double(totalPhotos) : 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "photo.stack.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accentGradient)
                Text("SlideRoll " + lm.s.statProgress).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(String(format: "%0.f%%", progress * 100))
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.surfaceHigh).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.accentGradient)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)
            HStack(spacing: 0) {
                summaryStat(value: "\(totalReviewed)", label: lm.s.statReviewed, color: Theme.accent)
                summaryDivider
                summaryStat(value: "\(kept)", label: lm.s.statKept, color: Theme.green)
                summaryDivider
                summaryStat(value: "\(toDelete)", label: lm.s.statToDelete, color: Theme.orange)
                summaryDivider
                summaryStat(value: "\(vm.totalDeletedCount)", label: lm.s.statDeleted, color: Theme.red)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
    }

    private func summaryStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View { Rectangle().fill(Theme.border).frame(width: 1, height: 32) }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }

    private var backgroundGlows: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.10)).frame(width: 280).blur(radius: 80).offset(x: 120, y: -200)
            Circle().fill(Theme.orange.opacity(0.07)).frame(width: 200).blur(radius: 60).offset(x: -80, y: 150)
        }
    }
}
