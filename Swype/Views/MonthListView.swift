import SwiftUI

// MARK: - Root Hub

struct MonthListView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var showTrash = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.bg.ignoresSafeArea()

                // Background glows
                backgroundGlows

                Group {
                    if vm.isLoading {
                        loadingView
                    } else if vm.yearGroups.isEmpty {
                        emptyView
                    } else {
                        yearList
                    }
                }

                if !vm.toDeleteIDs.isEmpty {
                    trashFloatingBar
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.toDeleteIDs.count)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navHeader }
            .sheet(isPresented: $showTrash) {
                TrashView().environment(vm)
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
    }

    // MARK: Nav

    private var navHeader: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accentGradient)
                Text("Swype")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    // MARK: Year List

    private var yearList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Summary header
                summaryHeader
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                LazyVStack(spacing: 14) {
                    ForEach(vm.yearGroups) { year in
                        NavigationLink(destination:
                            MonthsForYearView(year: year).environment(vm)
                        ) {
                            YearCard(year: year)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, vm.toDeleteIDs.isEmpty ? 40 : 110)
            }
        }
    }

    // MARK: Summary Header

    private var summaryHeader: some View {
        let totalPhotos = vm.yearGroups.reduce(0) { $0 + $1.total }
        let totalReviewed = vm.yearGroups.reduce(0) { $0 + $1.reviewed }
        let progress = totalPhotos > 0 ? Double(totalReviewed) / Double(totalPhotos) : 0

        return VStack(alignment: .leading, spacing: 16) {
            Text("Genel İlerleme")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .tracking(0.8)

            HStack(alignment: .bottom, spacing: 6) {
                Text("\(totalReviewed)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("/ \(totalPhotos)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 6)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.surfaceHigh)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accentGradient)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)

            HStack(spacing: 20) {
                summaryChip(value: "\(vm.toDeleteIDs.count)", label: "Silinecek", color: Theme.red)
                summaryChip(value: String(format: "%0.f%%", progress * 100), label: "Tamamlandı", color: Theme.green)
                summaryChip(value: "\(vm.yearGroups.count)", label: "Yıl", color: Theme.accent)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border, lineWidth: 1))
        )
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
                    Text("\(vm.toDeleteIDs.count) fotoğraf seçildi")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Silmek için dokun")
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
            Text("Fotoğraflar yükleniyor…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52))
                .foregroundStyle(Theme.textTertiary)
            Text("Fotoğraf Bulunamadı")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Year Card

struct YearCard: View {
    let year: YearGroup
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(year.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(year.months.count) ay · \(year.total) fotoğraf")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                percentBadge
            }

            // Stats row
            HStack(spacing: 0) {
                statBlock(value: "\(year.reviewed)", label: "İncelendi", color: Theme.green)
                Divider().background(Theme.border).frame(height: 32).padding(.horizontal, 12)
                statBlock(value: "\(year.total - year.reviewed)", label: "Bekliyor", color: Theme.orange)
                Divider().background(Theme.border).frame(height: 32).padding(.horizontal, 12)
                statBlock(value: "\(year.months.count)", label: "Ay", color: Theme.accent)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHigh).frame(height: 5)
                    Capsule()
                        .fill(progressGradient)
                        .frame(width: geo.size.width * (appeared ? year.progress : 0), height: 5)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1), value: appeared)
                }
            }
            .frame(height: 5)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }

    private var percentBadge: some View {
        Group {
            if year.isCompleted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                    Text("Tamam")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.greenGradient, in: Capsule())
            } else {
                Text(String(format: "%0.f%%", year.progress * 100))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
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
    @State private var selectedGroup: MonthGroup?
    @State private var showTrash = false

    private var currentYear: YearGroup? {
        vm.yearGroups.first(where: { $0.id == year.id })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(currentYear?.months ?? year.months) { group in
                        MonthCard(group: group)
                            .onTapGesture { selectedGroup = group }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, vm.toDeleteIDs.isEmpty ? 40 : 110)
            }

            if !vm.toDeleteIDs.isEmpty {
                trashFloatingBar
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.toDeleteIDs.isEmpty)
        .navigationTitle(year.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedGroup) { group in
            ReviewView(group: group).environment(vm)
        }
        .sheet(isPresented: $showTrash) {
            TrashView().environment(vm)
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
                    Text("\(vm.toDeleteIDs.count) fotoğraf seçildi")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Silmek için dokun")
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

    private var keepCount: Int   { group.decisions.values.filter { $0 == .keep }.count }
    private var deleteCount: Int { group.decisions.values.filter { $0 == .delete }.count }
    private var skipCount: Int   { group.decisions.values.filter { $0 == .skip }.count }
    private var remaining: Int   { group.total - group.reviewed - skipCount }

    var body: some View {
        VStack(spacing: 0) {
            // Top row
            HStack(spacing: 14) {
                CircularProgress(progress: group.progress, isCompleted: group.isCompleted)
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(group.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        if group.isCompleted {
                            Label("Tamam", systemImage: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.green, in: Capsule())
                        }
                    }
                    Text("\(group.reviewed) / \(group.total) fotoğraf incelendi")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(16)

            // Stats row — sadece en az biri sıfır değilse göster
            if group.reviewed > 0 {
                Divider().padding(.horizontal, 16)

                HStack(spacing: 0) {
                    miniStat(icon: "checkmark", value: keepCount, color: Theme.green, label: "Tutuldu")
                    miniDivider
                    miniStat(icon: "trash", value: deleteCount, color: Theme.red, label: "Silinecek")
                    miniDivider
                    miniStat(icon: "clock", value: skipCount, color: Theme.orange, label: "Atlandı")
                    miniDivider
                    miniStat(icon: "photo", value: remaining, color: Theme.textTertiary, label: "Bekliyor")
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
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
    }

    private func miniStat(icon: String, value: Int, color: Color, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text("\(value)")
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
