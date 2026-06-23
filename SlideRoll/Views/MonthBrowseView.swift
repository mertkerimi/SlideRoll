import SwiftUI
import Photos

struct MonthBrowseView: View {
    let group: MonthGroup
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    @State private var selectedID: String? = nil

    private var currentGroup: MonthGroup? {
        vm.monthGroups.first(where: { $0.id == group.id })
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(group.photoIDs, id: \.self) { photoID in
                            BrowseThumbnailCell(
                                photoID: photoID,
                                decision: currentGroup?.decisions[photoID] ?? .undecided
                            ) {
                                selectedID = photoID
                            }
                            .environment(vm)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(lm.s.monthTitle(from: group.id))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(lm.s.photosCount(group.total))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(lm.s.close) { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedID.map { BrowseItem(id: $0) } },
            set: { selectedID = $0?.id }
        )) { item in
            BrowsePhotoDetailView(photoID: item.id)
                .environment(vm)
                .environment(lm)
        }
    }
}

private struct BrowseItem: Identifiable { let id: String }

// MARK: - Thumbnail Cell

private struct BrowseThumbnailCell: View {
    let photoID: String
    let decision: PhotoDecision
    let onTap: () -> Void

    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var image: UIImage?

    private var cellSize: CGFloat { (UIScreen.main.bounds.width - 4) / 3 }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Theme.surface
                            .overlay(ProgressView().tint(Theme.accent).scaleEffect(0.6))
                    }
                }
                .frame(width: cellSize, height: cellSize)
                .clipped()

                if decision != .undecided {
                    decisionBadge
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 240, height: 240))
        }
    }

    @ViewBuilder
    private var decisionBadge: some View {
        let (icon, color): (String, Color) = {
            switch decision {
            case .keep:   return ("checkmark", Theme.green)
            case .delete: return ("trash.fill", Theme.red)
            case .skip:   return ("clock.fill", Theme.orange)
            default:      return ("", .clear)
            }
        }()

        ZStack {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Photo Detail

struct BrowsePhotoDetailView: View {
    let photoID: String

    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    @State private var image: UIImage?
    @State private var decision: PhotoDecision = .undecided
    @State private var photoDate: Date = Date()
    @State private var animating = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer()
                mediaArea
                Spacer()

                if decision != .undecided {
                    currentDecisionBadge
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 12)
                }

                actionButtons
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: decision)
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 1000, height: 1000))
            if let asset = vm.asset(for: photoID) {
                photoDate = asset.creationDate ?? Date()
            }
            for g in vm.monthGroups {
                if let d = g.decisions[photoID] { decision = d; break }
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12), in: Circle())
            }
            Spacer()
            Text(formatDate(photoDate))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var mediaArea: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .overlay(ProgressView().tint(.white))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(.horizontal, 16)
        .scaleEffect(animating ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animating)
    }

    private var currentDecisionBadge: some View {
        let isDelete = decision == .delete
        let isSkip = decision == .skip
        let icon = isDelete ? "trash.fill" : isSkip ? "clock.fill" : "checkmark.circle.fill"
        let label = isDelete ? lm.s.deleteBadge : isSkip ? lm.s.laterBadge : lm.s.keepBadge
        let color: Color = isDelete ? Theme.red : isSkip ? Theme.orange : Theme.green

        return HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label).font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(color.opacity(0.15)))
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button { makeDecision(.delete) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                    Text(lm.s.deleteBadge).font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(decision == .delete ? .white : Theme.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(decision == .delete ? Theme.red : Theme.red.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.red.opacity(decision == .delete ? 0 : 0.3), lineWidth: 1))
                )
            }
            .disabled(animating)

            Button { makeDecision(.keep) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold))
                    Text(lm.s.keepBadge).font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(decision == .keep ? .white : Theme.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(decision == .keep ? Theme.green : Theme.green.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.green.opacity(decision == .keep ? 0 : 0.3), lineWidth: 1))
                )
            }
            .disabled(animating)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private func makeDecision(_ d: PhotoDecision) {
        animating = true
        withAnimation { decision = d }
        vm.applyDecisionGlobal(d, to: photoID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animating = false
            dismiss()
        }
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = lm.s.locale
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: d)
    }
}
