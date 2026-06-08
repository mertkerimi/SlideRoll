import SwiftUI

// Identifiable wrapper so we can use .sheet(item:)
struct IdentifiablePhoto: Identifiable {
    let id: String
    let bytes: Int64
    let date: Date
}

struct LargestPhotoRow: View {
    let photoID: String
    let bytes: Int64
    let date: Date

    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @State private var image: UIImage?

    private var dateString: String {
        let f = DateFormatter()
        f.locale = lm.s.locale
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private var decision: PhotoDecision? {
        for group in vm.monthGroups {
            if let d = group.decisions[photoID] { return d }
        }
        return nil
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Full-width photo
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Theme.surfaceHigh
                        .overlay(ProgressView().tint(Theme.accent))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipped()

            // Gradient overlay for legibility
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Info row
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(formatBytes(bytes))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(dateString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                if let d = decision {
                    decisionTag(d)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 800, height: 500))
        }
    }

    private func decisionTag(_ d: PhotoDecision) -> some View {
        let isDelete = d == .delete
        return HStack(spacing: 4) {
            Image(systemName: isDelete ? "trash.fill" : "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text(isDelete ? lm.s.deleteBadge : lm.s.keepBadge)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(isDelete ? Theme.red : Theme.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill((isDelete ? Theme.red : Theme.green).opacity(0.2))
                .overlay(Capsule().stroke((isDelete ? Theme.red : Theme.green).opacity(0.4), lineWidth: 1))
        )
    }

    private func formatBytes(_ b: Int64) -> String {
        let gb = Double(b) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(b) / 1_048_576)
    }
}
