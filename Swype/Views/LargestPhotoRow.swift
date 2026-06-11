import SwiftUI

struct IdentifiablePhoto: Identifiable {
    let id: String
    let bytes: Int64
    let date: Date
    var isVideo: Bool = false
}

struct LargestPhotoRow: View {
    let photoID: String
    let bytes: Int64
    let date: Date
    var isVideo: Bool = false
    var duration: TimeInterval? = nil

    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            // Info — left
            VStack(alignment: .leading, spacing: 4) {
                Text(formatBytes(bytes))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(dateString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                if isVideo, let dur = duration {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                        Text(formatDuration(dur))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Theme.orange)
                }
            }

            Spacer()

            // Thumbnail — right
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.surfaceHigh)
                if let img = thumbnail {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    Image(systemName: isVideo ? "video.fill" : "photo.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textTertiary)
                }
                if isVideo {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 3)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surfaceHigh, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task {
            thumbnail = await vm.loadImage(for: photoID, targetSize: CGSize(width: 120, height: 120))
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.locale = lm.s.locale
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func formatBytes(_ b: Int64) -> String {
        let gb = Double(b) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(b) / 1_048_576)
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60, sec = Int(s) % 60
        return String(format: "%d:%02d", m, sec)
    }
}
