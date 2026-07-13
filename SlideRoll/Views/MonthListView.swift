import SwiftUI
import Photos

// MARK: - Root Hub

struct MonthListView: View {
    @Binding var selectedTab: AppTab
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(AdManager.self) var adManager
    @Environment(SubscriptionManager.self) var subManager
    @State private var showTrash = false
    @State private var showShuffle = false
    @State private var navPath: [YearGroup] = []
    @State private var resumeGroup: MonthGroup? = nil

    private var lastReviewedGroup: MonthGroup? {
        guard let id = UserDefaults.standard.string(forKey: "lastReviewedMonthID") else { return nil }
        return vm.monthGroups.first(where: { $0.id == id && !$0.isCompleted })
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .bottom) {
                Theme.bg.ignoresSafeArea()

                backgroundGlows

                Group {
                    if vm.authStatus == .denied || vm.authStatus == .restricted {
                        deniedView
                    } else if vm.isLoading {
                        loadingView
                    } else if vm.yearGroups.isEmpty {
                        emptyView
                    } else {
                        yearList
                    }
                }

                if !vm.toDeleteIDs.isEmpty {
                    trashFloatingBar
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.toDeleteIDs.count)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: YearGroup.self) { year in
                MonthsForYearView(year: year).environment(vm).environment(lm).environment(adManager).environment(subManager)
            }
            .sheet(isPresented: $showTrash) {
                TrashView().environment(vm).environment(lm)
            }
            .sheet(item: $resumeGroup) { group in
                ReviewView(group: group).environment(vm).environment(lm).environment(adManager).environment(subManager)
            }
            .fullScreenCover(isPresented: $showShuffle) {
                GlobalReviewView().environment(vm).environment(lm).environment(adManager).environment(subManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: .tourNavigateToFirstYear)) { _ in
                if let firstYear = vm.yearGroups.first {
                    navPath = [firstYear]
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .widgetOpenYear)) { note in
                guard let yearID = note.object as? String,
                      let match = vm.yearGroups.first(where: { $0.id == yearID }) else { return }
                navPath = [match]
            }
            .onReceive(NotificationCenter.default.publisher(for: .widgetOpenShuffle)) { _ in
                showShuffle = true
            }
        }
    }

    // MARK: Background

    private var backgroundGlows: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.12))
                .frame(width: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -300)
            Circle()
                .fill(Theme.accentEnd.opacity(0.08))
                .frame(width: 250)
                .blur(radius: 60)
                .offset(x: 140, y: -100)
        }
        // No .drawingGroup() — it rasterizes to a bounding box and clips the
        // soft blur into a hard rectangular edge.
        .allowsHitTesting(false)
    }

    // MARK: Year List

    private var yearList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                inlineHeader
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                summaryHeader
                    .padding(.horizontal, 24)
                    .padding(.bottom, vm.authStatus == .limited ? 8 : 24)

                if vm.authStatus == .limited {
                    HStack {
                        Button {
                            withAnimation { selectedTab = .settings }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "lock.rectangle")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Fotoğraf Erişimini Değiştir →")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }

                LazyVStack(spacing: 14) {
                    ForEach(Array(vm.yearGroups.enumerated()), id: \.element.id) { index, year in
                        Button { navPath.append(year) } label: {
                            YearCard(year: year).environment(lm)
                        }
                        .buttonStyle(.plain)
                        .anchorPreference(key: TourAnchorKey.self, value: .bounds) { anchor in
                            index == 0 ? [.yearCards: anchor] : [:]
                        }
                        .modifier(SlideInModifier(delay: Double(index) * 0.07))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, vm.toDeleteIDs.isEmpty ? 76 : 152)
            }
        }
    }

    // MARK: Inline Header

    private var inlineHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("SplashIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text("SlideRoll")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Spacer()
        }
    }

    // MARK: Summary Header

    private var summaryHeader: some View {
        let totalPhotos   = vm.yearGroups.reduce(0) { $0 + $1.total }
        let totalReviewed = vm.yearGroups.reduce(0) { $0 + $1.reviewed }
        let progress = totalPhotos > 0 ? Double(totalReviewed) / Double(totalPhotos) : 0
        let s = lm.s

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(s.overallProgress)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(0.8)
                Spacer()
                if let group = lastReviewedGroup {
                    Button { resumeGroup = group } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(s.actionContinue)
                                .font(.system(size: 12, weight: .semibold))
                            Text("· \(s.monthTitle(from: group.id))")
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.7)
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Theme.accent.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .bottom, spacing: 6) {
                    Text(totalReviewed.fmtCount)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("/ \(totalPhotos.fmtCount)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.bottom, 4)
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.surfaceHigh)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accentGradient)
                        .frame(maxWidth: .infinity, maxHeight: 6)
                        .scaleEffect(x: progress, y: 1, anchor: .leading)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
                }
                .frame(height: 6)
            }

            HStack(spacing: 0) {
                summaryChip(value: "\(vm.toDeleteIDs.count)", label: s.toDeleteStat, color: Theme.red)
                Divider().frame(height: 28).padding(.horizontal, 8)
                summaryChip(value: String(format: "%0.f%%", progress * 100), label: s.completedLabel, color: Theme.green)
                Divider().frame(height: 28).padding(.horizontal, 8)
                summaryChip(value: "\(vm.yearGroups.count)", label: s.yearLabel, color: Theme.accent)
            }

            Button { showShuffle = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 14, weight: .semibold))
                    Text(s.shuffleHint)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.accent.opacity(0.20), lineWidth: 1))
            }

            if vm.todayDecisionCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.orange)
                    Text(s.todayCount(vm.todayDecisionCount))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
        .tourAnchor(.summaryCard)
    }

    private func summaryChip(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: Trash Bar

    private var trashFloatingBar: some View {
        Button { showTrash = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.red.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lm.s.photosSelected(vm.toDeleteIDs.count))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(lm.s.tapToDelete)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Theme.red.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Theme.red.opacity(0.2), radius: 20, y: 8)
            )
        }
        .padding(.horizontal, 20)
    }

    // MARK: States

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(Theme.accent)
                .scaleEffect(1.4)
            Text(lm.s.loadingPhotos)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedView: some View {
        VStack(spacing: 0) {
            inlineHeader
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)

            Spacer()

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.12))
                            .frame(width: 80, height: 80)
                            .overlay(Circle().stroke(Theme.accent.opacity(0.25), lineWidth: 1.5))
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }

                    Text(lm.s.allowPhotosDeniedReason)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52))
                .foregroundStyle(Theme.textTertiary)
            Text(lm.s.noPhotosFound)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Year Card

struct YearCard: View {
    let year: YearGroup
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let s = lm.s
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(year.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(s.monthsPhotosAndVideos(months: year.months.count, photos: year.photoCount, videos: year.videoCount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                percentBadge(s: s)
            }

            HStack(spacing: 0) {
                statBlock(value: "\(year.reviewed)", label: s.reviewedLabel, color: Theme.green)
                Divider().background(Theme.border).frame(height: 32).padding(.horizontal, 12)
                statBlock(value: "\(vm.deletedCountByYear[year.id, default: 0])", label: s.statDeleted, color: Theme.red)
                Divider().background(Theme.border).frame(height: 32).padding(.horizontal, 12)
                statBlock(value: "\(year.total - year.reviewed)", label: s.pendingLabel, color: Theme.orange)
                Divider().background(Theme.border).frame(height: 32).padding(.horizontal, 12)
                statBlock(value: "\(year.months.count)", label: s.monthLabel, color: Theme.accent)
            }

            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceHigh).frame(height: 5)
                Capsule()
                    .fill(progressGradient)
                    .frame(maxWidth: .infinity, maxHeight: 5)
                    .scaleEffect(x: year.progress, y: 1, anchor: .leading)
            }
            .frame(height: 5)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(cardGradientOverlay)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
        .compositingGroup()
        .shadow(color: cardShadowColor.opacity(0.10), radius: 10, y: 4)
    }

    private var cardOpacity: Double { colorScheme == .dark ? 0.08 : 0.14 }
    private var borderOpacity: Double { colorScheme == .dark ? 0.20 : 0.35 }

    private var cardGradientOverlay: LinearGradient {
        let color: Color
        if year.isCompleted { color = Theme.green }
        else if year.progress > 0 { color = Theme.orange }
        else { color = Theme.accent }
        return LinearGradient(
            colors: [color.opacity(cardOpacity), color.opacity(0)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private var cardBorderColor: Color {
        if year.isCompleted { return Theme.green.opacity(borderOpacity) }
        if year.progress > 0 { return Theme.orange.opacity(borderOpacity * 0.9) }
        return Theme.border
    }

    private var cardShadowColor: Color {
        if year.isCompleted { return Theme.green }
        if year.progress > 0 { return Theme.orange }
        return .black
    }

    private func percentBadge(s: Strings) -> some View {
        Group {
            if year.isCompleted {
                Label(s.done, systemImage: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.green, in: Capsule())
            } else if year.progress > 0 {
                Label(s.actionContinue, systemImage: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.orange.opacity(0.15), in: Capsule())
            } else {
                Label(s.actionStart, systemImage: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.15), in: Capsule())
            }
        }
    }

    private func statBlock(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var progressGradient: LinearGradient {
        year.isCompleted ? Theme.greenGradient :
        (year.progress > 0.5 ? Theme.accentGradient : Theme.orangeGradient)
    }

}


// MARK: - Months for Year

struct MonthsForYearView: View {
    let year: YearGroup
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(AdManager.self) var adManager
    @Environment(SubscriptionManager.self) var subManager
    @State private var selectedGroup: MonthGroup?
    @State private var showTrash = false

    // Read monthGroups directly so @Observable fires immediately on any decision change,
    // without relying on the yearGroups→currentYear computed chain.
    private var currentMonths: [MonthGroup] {
        vm.monthGroups
            .filter { String($0.id.prefix(4)) == year.id }
            .sorted { $0.id > $1.id }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(Array(currentMonths.enumerated()), id: \.element.id) { index, group in
                        MonthCard(group: group).environment(lm)
                            .onTapGesture { selectedGroup = group }
                            .anchorPreference(key: TourAnchorKey.self, value: .bounds) { anchor in
                                index == 0 ? [.monthCards: anchor] : [:]
                            }
                            .modifier(SlideInModifier(delay: Double(index) * 0.06))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, vm.toDeleteIDs.isEmpty ? 76 : 152)
            }

            if !vm.toDeleteIDs.isEmpty {
                trashFloatingBar
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.toDeleteIDs.isEmpty)
        .navigationTitle(year.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedGroup) { group in
            ReviewView(group: group).environment(vm).environment(lm).environment(adManager).environment(subManager)
        }
        .sheet(isPresented: $showTrash) {
            TrashView().environment(vm).environment(lm)
        }
        .onChange(of: selectedGroup) { _, group in
            if let group {
                UserDefaults.standard.set(group.id, forKey: "lastReviewedMonthID")
            }
        }
    }

    private var trashFloatingBar: some View {
        Button { showTrash = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.red.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lm.s.photosSelected(vm.toDeleteIDs.count))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(lm.s.tapToDelete)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Theme.red.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Theme.red.opacity(0.2), radius: 20, y: 8)
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Month Card

struct MonthCard: View {
    let group: MonthGroup
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.colorScheme) var colorScheme

    private var keepCount: Int   { group.decisions.values.filter { $0 == .keep }.count }
    private var deleteCount: Int { group.decisions.values.filter { $0 == .delete }.count }
    private var skipCount: Int   { group.decisions.values.filter { $0 == .skip }.count }
    private var remaining: Int   { group.total - group.reviewed - skipCount }

    var body: some View {
        let s = lm.s
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CircularProgress(progress: group.progress, isCompleted: group.isCompleted)
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lm.s.monthTitle(from: group.id))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(s.photosReviewedOfWithVideos(reviewed: group.reviewed, total: group.total, videos: group.videoCount))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                actionBadge(s: s)
            }
            .padding(16)

            if group.reviewed > 0 {
                Divider().padding(.horizontal, 16)

                HStack(spacing: 0) {
                    miniStat(icon: "checkmark", value: keepCount, color: Theme.green, label: s.keptStat)
                    miniDivider
                    miniStat(icon: "trash.fill", value: vm.deletedCountByMonth[group.id, default: 0], color: Theme.red, label: s.statDeleted)
                    miniDivider
                    miniStat(icon: "clock", value: skipCount, color: Theme.orange, label: s.skippedStat)
                    miniDivider
                    miniStat(icon: "trash", value: deleteCount, color: Theme.red.opacity(0.7), label: s.toDeleteStat)
                    miniDivider
                    miniStat(icon: "photo", value: remaining, color: Theme.textTertiary, label: s.waitingStat)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(monthCardGradient)
                        .animation(.easeInOut(duration: 0.4), value: group.progress)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(monthCardBorder, lineWidth: 1)
                        .animation(.easeInOut(duration: 0.4), value: group.progress)
                )
        )
    }

    private var cardOpacity: Double { colorScheme == .dark ? 0.08 : 0.14 }
    private var borderOpacity: Double { colorScheme == .dark ? 0.20 : 0.35 }

    private func actionBadge(s: Strings) -> some View {
        Group {
            if group.isCompleted {
                Label(s.done, systemImage: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.green, in: Capsule())
            } else if group.reviewed > 0 {
                Label(s.actionContinue, systemImage: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.orange.opacity(0.15), in: Capsule())
            } else {
                Label(s.actionStart, systemImage: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.15), in: Capsule())
            }
        }
    }

    private var monthCardGradient: LinearGradient {
        let color: Color = group.isCompleted ? Theme.green : (group.reviewed > 0 ? Theme.orange : .clear)
        return LinearGradient(
            colors: [color.opacity(cardOpacity), color.opacity(0)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    private var monthCardBorder: Color {
        if group.isCompleted { return Theme.green.opacity(borderOpacity) }
        if group.reviewed > 0 { return Theme.orange.opacity(borderOpacity * 0.9) }
        return Theme.border
    }

    private func miniStat(icon: String, value: Int, color: Color, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text(value.fmtCount)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(value > 0 ? color : Theme.textTertiary)
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var miniDivider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: 1, height: 28)
    }
}

// MARK: - Circular Progress

struct CircularProgress: View {
    let progress: Double
    let isCompleted: Bool

    private var ringColor: LinearGradient {
        isCompleted ? Theme.greenGradient :
        (progress > 0.5 ? Theme.accentGradient : Theme.orangeGradient)
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.surfaceHigh, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            Text(String(format: "%0.f%%", progress * 100))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
