import SwiftUI

struct TrashView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    @State private var showConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var allSelected = false

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        let s = lm.s
        NavigationStack {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()
            backgroundGlows

            if vm.toDeleteIDs.isEmpty {
                emptyView
            } else {
                scrollGrid
                bottomBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(s.trashTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(s.photosCount(vm.toDeleteIDs.count))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(s.close) { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        allSelected.toggle()
                    }
                } label: {
                    Text(allSelected ? s.cancel : s.selectAll)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(allSelected ? Theme.red : Theme.accent)
                }
            }
        }
        .confirmationDialog(s.cannotUndo, isPresented: $showConfirm, titleVisibility: .visible) {
            Button(s.permanentlyDeleteN(vm.toDeleteIDs.count), role: .destructive) {
                Task { await permanentDelete() }
            }
            Button(s.cancel, role: .cancel) {}
        } message: {
            Text(s.permanentlyDeleteMsg(vm.toDeleteIDs.count))
        }
        .alert(s.error, isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button(s.ok, role: .cancel) {}
        } message: { Text(deleteError ?? "") }
        }
    }

    private var backgroundGlows: some View {
        ZStack {
            Circle()
                .fill(Theme.red.opacity(0.10))
                .frame(width: 260).blur(radius: 70)
                .offset(x: 100, y: -200)
        }
    }

    private var scrollGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(vm.toDeleteIDs, id: \.self) { id in
                    TrashThumbnailView(photoID: id) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            vm.removeFromTrash(photoID: id)
                        }
                    }
                    .environment(vm)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.5).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 130)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.toDeleteIDs.count)
        }
    }

    private var bottomBar: some View {
        let s = lm.s
        return VStack(spacing: 0) {
            LinearGradient(
                colors: [Theme.bg.opacity(0), Theme.bg],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 48)

            VStack(spacing: 10) {
                if allSelected {
                    // Silmekten Vazgeç
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            vm.removeAllFromTrash()
                            allSelected = false
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .bold))
                            Text(s.cancelAllDeletes)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.orange)
                        )
                        .shadow(color: Theme.orange.opacity(0.45), radius: 16, y: 8)
                    }

                    Text(s.cancelAllDeletesHint)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                } else {
                    Button { showConfirm = true } label: {
                        Group {
                            if isDeleting {
                                HStack(spacing: 12) {
                                    ProgressView().tint(.white)
                                    Text(s.deleting).font(.system(size: 16, weight: .bold))
                                }
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(s.permanentlyDeleteButton(vm.toDeleteIDs.count))
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Theme.redGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Theme.red.opacity(0.45), radius: 16, y: 8)
                    }
                    .disabled(isDeleting)

                    Text(s.cannotUndoShort)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .background(Theme.bg)
        }
    }

    private var emptyView: some View {
        let s = lm.s
        return VStack(spacing: 16) {
            Image(systemName: "trash.slash.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.textTertiary)
            Text(s.noPhotosToDelete)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(s.swipeLeftHint)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func permanentDelete() async {
        isDeleting = true
        do {
            try await vm.permanentlyDeleteTrash()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - Thumbnail

struct TrashThumbnailView: View {
    let photoID: String
    let onRemove: () -> Void

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
                        .overlay(ProgressView().tint(Theme.accent).scaleEffect(0.7))
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )

            Button { onRemove() } label: {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.6))
                        .frame(width: 22, height: 22)
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(5)
        }
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 240, height: 240))
        }
    }
}
