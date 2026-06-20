import SwiftUI
import Photos
import PhotosUI
import AVKit

// MARK: - Preview Sheet

struct TrashPreviewSheet: View {
    let photoID: String
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    @State private var stage: Stage = .loading
    @State private var image: UIImage?
    @State private var livePhoto: PHLivePhoto?
    @State private var player: AVPlayer?

    private enum Stage { case loading, photo, livePhoto, video, failed }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch stage {
            case .loading:
                ProgressView().tint(.white).scaleEffect(1.4)

            case .photo:
                if let img = image {
                    ZoomableImageView(image: img)
                }

            case .livePhoto:
                if let lp = livePhoto {
                    TrashLivePhotoView(livePhoto: lp)
                        .ignoresSafeArea()
                } else if let img = image {
                    // Still shown while live photo loads
                    ZoomableImageView(image: img)
                } else {
                    ProgressView().tint(.white).scaleEffect(1.4)
                }

            case .video:
                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                        .onDisappear { player.pause() }
                } else {
                    ProgressView().tint(.white).scaleEffect(1.4)
                }

            case .failed:
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(lm.s.videoLoadError)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 56)
        }
        .task { await loadMedia() }
    }

    // MARK: - Load

    private func loadMedia() async {
        guard let asset = vm.asset(for: photoID) else {
            stage = .failed; return
        }

        if asset.mediaType == .video {
            await loadVideo(asset: asset)
        } else if asset.mediaSubtypes.contains(.photoLive) {
            await loadLivePhoto(asset: asset)
        } else {
            await loadPhoto()
        }
    }

    private func loadPhoto() async {
        image = await vm.loadThumbnail(for: photoID)
        stage = .photo
        if let full = await vm.loadImage(for: photoID, targetSize: CGSize(width: 3000, height: 3000)) {
            image = full
        }
    }

    private func loadLivePhoto(asset: PHAsset) async {
        image = await vm.loadThumbnail(for: photoID)
        stage = .livePhoto
        livePhoto = await vm.loadLivePhoto(for: photoID, targetSize: CGSize(width: 1080, height: 1440))
    }

    private func loadVideo(asset: PHAsset) async {
        let opts = PHVideoRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .automatic

        let avAsset: AVAsset? = await withCheckedContinuation { cont in
            var resumed = false
            PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { av, _, _ in
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: av)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: nil)
            }
        }

        guard let avAsset else { stage = .failed; return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
        stage = .video
        player?.play()
    }
}

// MARK: - Pinch-to-zoom image (for static photos)

private struct ZoomableImageView: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss

    private var dismissProgress: CGFloat {
        let d = sqrt(pow(dragOffset.width, 2) + pow(dragOffset.height, 2))
        return min(d / 180, 1)
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale * (1 - dismissProgress * 0.2))
            .offset(x: offset.width + dragOffset.width,
                    y: offset.height + dragOffset.height)
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { scale = max(1, lastScale * $0) }
                        .onEnded { _ in
                            if scale < 1 { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { scale = 1; offset = .zero } }
                            lastScale = scale
                        },
                    DragGesture()
                        .onChanged { v in
                            if scale > 1.01 {
                                offset = CGSize(width: lastOffset.width + v.translation.width,
                                               height: lastOffset.height + v.translation.height)
                            } else {
                                dragOffset = v.translation
                            }
                        }
                        .onEnded { v in
                            if scale > 1.01 {
                                lastOffset = offset
                            } else {
                                let d = sqrt(pow(v.translation.width, 2) + pow(v.translation.height, 2))
                                if d > 120 { dismiss() }
                                else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragOffset = .zero } }
                            }
                        }
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if scale > 1 { scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero }
                    else { scale = 2.5; lastScale = 2.5 }
                }
            }
    }
}

// MARK: - PHLivePhotoView wrapper (autoplays)

struct TrashLivePhotoView: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let v = PHLivePhotoView()
        v.livePhoto = livePhoto
        v.contentMode = .scaleAspectFit
        v.clipsToBounds = true
        v.isMuted = false
        return v
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
        uiView.startPlayback(with: .full)
    }
}
