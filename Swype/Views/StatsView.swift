import SwiftUI

struct StatsView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm

    @State private var initialLoad = true
    @State private var showDuplicates = false
    @State private var selectedLargest: IdentifiablePhoto? = nil
    private var isLoading: Bool { initialLoad || vm.statsLoading }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            backgroundGlows

            if isLoading {
                loadingView.transition(.opacity)
            } else {
                content.transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .sheet(isPresented: $showDuplicates) {
            DuplicatesView().environment(vm).environment(lm)
        }
        .sheet(item: $selectedLargest) { photo in
            LargestPhotoDetailView(photoID: photo.id, bytes: photo.bytes, date: photo.date)
                .environment(vm).environment(lm)
        }
        .task { await vm.loadLibraryStats(); initialLoad = false }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.12)).frame(width: 90, height: 90)
                ProgressView().tint(Theme.accent).scaleEffect(1.5)
            }
            VStack(spacing: 8) {
                Text(lm.s.statCalculating)
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Text(lm.s.statCalculatingHint)
                    .font(.system(size: 13)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Media row
                HStack(spacing: 12) {
                    mediaCard(icon: "photo.fill", iconColor: Theme.accent,
                              title: lm.s.statPhotos, count: vm.photoCount, bytes: vm.photoBytes)
                    mediaCard(icon: "video.fill", iconColor: Theme.orange,
                              title: lm.s.statVideos, count: vm.videoCount, bytes: vm.videoBytes)
                }

                // Largest photos section
                if !vm.largestPhotos.isEmpty {
                    largestPhotosCard
                }

                // Year chart
                if !vm.yearlyStorage.isEmpty {
                    yearChartCard
                }

                // Swype progress
                swypeCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Largest Photos Card

    private var largestPhotosCard: some View {
        let items = vm.largestPhotos.map { IdentifiablePhoto(id: $0.id, bytes: $0.bytes, date: $0.date) }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(lm.s.statLargestPhotos)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Button { selectedLargest = item } label: {
                        LargestPhotoRow(photoID: item.id, bytes: item.bytes, date: item.date)
                            .environment(vm)
                            .environment(lm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
    }

    // MARK: - Media Card (half width)

    private func mediaCard(icon: String, iconColor: Color, title: String, count: Int, bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(formatBytes(bytes))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary)
                Text(lm.s.statItemCount(count)).font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
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

    // MARK: - Swype Card

    private var swypeCard: some View {
        let totalReviewed = vm.monthGroups.reduce(0) { $0 + $1.reviewed }
        let totalPhotos   = vm.monthGroups.reduce(0) { $0 + $1.total }
        let toDelete      = vm.toDeleteIDs.count
        let kept          = vm.monthGroups.reduce(0) { $0 + $1.decisions.values.filter { $0 == .keep }.count }
        let progress      = totalPhotos > 0 ? Double(totalReviewed) / Double(totalPhotos) : 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "photo.stack.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accentGradient)
                Text("Swype " + lm.s.statProgress).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textPrimary)
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
                swypeStat(value: "\(totalReviewed)", label: lm.s.statReviewed, color: Theme.accent)
                swypeDivider
                swypeStat(value: "\(kept)", label: lm.s.statKept, color: Theme.green)
                swypeDivider
                swypeStat(value: "\(toDelete)", label: lm.s.statToDelete, color: Theme.orange)
                swypeDivider
                swypeStat(value: "\(vm.totalDeletedCount)", label: lm.s.statDeleted, color: Theme.red)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
    }

    private func swypeStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var swypeDivider: some View { Rectangle().fill(Theme.border).frame(width: 1, height: 32) }

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
