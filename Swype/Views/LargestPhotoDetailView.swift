import SwiftUI

struct LargestPhotoDetailView: View {
    let photoID: String
    let bytes: Int64
    let date: Date

    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    @State private var image: UIImage?
    @State private var decision: PhotoDecision? = nil
    @State private var animating = false

    private var dateString: String {
        let f = DateFormatter()
        f.locale = lm.s.locale
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: date)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        HStack(spacing: 5) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(formatBytes(bytes))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text(dateString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Photo
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.white.opacity(0.08), lineWidth: 1)
                            )
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

                Spacer()

                // Decision result
                if let dec = decision {
                    decisionBadge(dec)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 12)
                }

                // Action buttons
                HStack(spacing: 16) {
                    // Delete
                    Button {
                        makeDecision(.delete)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text(lm.s.deleteBadge)
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(decision == .delete ? .white : Theme.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(decision == .delete ? Theme.red : Theme.red.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Theme.red.opacity(decision == .delete ? 0 : 0.3), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(animating)

                    // Keep
                    Button {
                        makeDecision(.keep)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .semibold))
                            Text(lm.s.keepBadge)
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(decision == .keep ? .white : Theme.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(decision == .keep ? Theme.green : Theme.green.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Theme.green.opacity(decision == .keep ? 0 : 0.3), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(animating)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: decision)
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 1000, height: 1000))
            // Reflect existing decision if any
            for group in vm.monthGroups {
                if let d = group.decisions[photoID] { decision = d; break }
            }
        }
    }

    private func makeDecision(_ d: PhotoDecision) {
        animating = true
        withAnimation { decision = d }
        vm.applyDecisionGlobal(d, to: photoID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            animating = false
            dismiss()
        }
    }

    private func decisionBadge(_ d: PhotoDecision) -> some View {
        let isDelete = d == .delete
        return HStack(spacing: 6) {
            Image(systemName: isDelete ? "trash.fill" : "checkmark.circle.fill")
            Text(isDelete ? lm.s.deleteBadge : lm.s.keepBadge)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(isDelete ? Theme.red : Theme.green)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule().fill((isDelete ? Theme.red : Theme.green).opacity(0.15))
        )
    }

    private func formatBytes(_ b: Int64) -> String {
        let gb = Double(b) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(b) / 1_048_576)
    }
}
