import SwiftUI
import AVKit
import Photos
import PhotosUI

enum SwipeDirection {
    case keep, delete, skip, none
}

struct PhotoCardView: View {
    let photoID: String
    let onSwipe: (SwipeDirection) -> Void
    let onTapUndo: () -> Void

    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @State private var offset: CGSize = .zero
    @State private var image: UIImage?
    @State private var isDragging = false
    @State private var isVideo = false
    @State private var player: AVPlayer?
    @State private var isVideoLoading = false
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var videoDurationSecs: Double = 0
    @State private var isSeeking = false
    @State private var timeObserver: Any?

    @State private var isLivePhoto = false
    @State private var livePhoto: PHLivePhoto?
    @State private var isLivePhotoPlaying = false
    @State private var isLivePhotoLoading = false

    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var isLoadingShare = false

    // Zoom state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero
    @State private var lastZoomOffset: CGSize = .zero
    private var isZoomed: Bool { scale > 1.01 }

    private var dragDirection: SwipeDirection {
        let w = offset.width, h = offset.height
        if abs(w) > abs(h) * 0.8 {
            if w > 40 { return .keep }
            if w < -40 { return .delete }
        } else if h < -40 {
            return .skip
        }
        return .none
    }

    private var rotation: Double { isZoomed ? 0 : Double(offset.width / 22) }
    private var keepOpacity: Double   { isZoomed ? 0 : max(0, min(1, Double(offset.width) / 80)) }
    private var deleteOpacity: Double { isZoomed ? 0 : max(0, min(1, Double(-offset.width) / 80)) }
    private var skipOpacity: Double   { isZoomed ? 0 : max(0, min(1, Double(-offset.height) / 80)) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                photoLayer(size: geo.size)
                keepBadge.opacity(keepOpacity)
                deleteBadge.opacity(deleteOpacity)
                skipBadge.opacity(skipOpacity)
                shareButton
                favoriteButton
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .offset(isZoomed ? zoomOffset : offset)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(isZoomed ? scale : 1.0)
            .gesture(combinedDragGesture)
            .gesture(magnifyGesture)
            .onTapGesture {
                if isZoomed {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scale = 1.0; lastScale = 1.0
                        zoomOffset = .zero; lastZoomOffset = .zero
                    }
                } else if !isDragging {
                    if isVideo {
                        handleVideoTap()
                    } else if isLivePhoto {
                        handleLivePhotoTap()
                    } else {
                        onTapUndo()
                    }
                }
            }
        }
        .task {
            isVideo = vm.isVideo(for: photoID)
            isLivePhoto = vm.isLivePhoto(for: photoID)
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 700, height: 900))
            if isLivePhoto {
                let lp = await vm.loadLivePhoto(for: photoID, targetSize: CGSize(width: 700, height: 900))
                livePhoto = lp
                isLivePhotoPlaying = true
            }
        }
        .onDisappear {
            if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
            player?.pause()
            player = nil
            isPlaying = false
            currentTime = 0
            videoDurationSecs = 0
            isLivePhotoPlaying = false
            livePhoto = nil
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
                .presentationDetents([.medium, .large])
        }
    }

    private func handleVideoTap() {
        if let player {
            if isPlaying {
                player.pause()
                isPlaying = false
            } else {
                player.play()
                isPlaying = true
            }
        } else {
            loadInlineVideo()
        }
    }

    private func loadInlineVideo() {
        guard !isVideoLoading, let asset = vm.asset(for: photoID) else { return }
        isVideoLoading = true
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            DispatchQueue.main.async {
                guard let avAsset else { self.isVideoLoading = false; return }
                let p = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                p.play()
                self.player = p
                self.isPlaying = true
                self.isVideoLoading = false
                self.videoDurationSecs = avAsset.duration.seconds
                // Loop
                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                    object: p.currentItem, queue: .main) { _ in
                    p.seek(to: .zero); p.play()
                }
                // Time observer — update seek bar every 0.1s
                let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                self.timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                    guard !self.isSeeking else { return }
                    self.currentTime = time.seconds
                }
            }
        }
    }

    private func handleLivePhotoTap() {
        if livePhoto != nil {
            isLivePhotoPlaying.toggle()
        } else {
            loadLivePhotoAndPlay()
        }
    }

    private func loadLivePhotoAndPlay() {
        guard !isLivePhotoLoading else { return }
        isLivePhotoLoading = true
        Task {
            let lp = await vm.loadLivePhoto(for: photoID, targetSize: CGSize(width: 700, height: 900))
            livePhoto = lp
            isLivePhotoPlaying = true
            isLivePhotoLoading = false
        }
    }

    // MARK: - Photo/Video Layer

    private func photoLayer(size: CGSize) -> some View {
        ZStack {
            Color.black
            if let p = player {
                InlineVideoPlayer(player: p)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else if let lp = livePhoto {
                LivePhotoPlayerView(livePhoto: lp, isPlaying: isLivePhotoPlaying)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity.animation(.easeIn(duration: 0.25)))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: isVideo ? "video" : "photo")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.textTertiary)
                    ProgressView().tint(Theme.accent)
                }
            }

            if isVideo { videoOverlay }
            if isLivePhoto { livePhotoOverlay }
        }
    }

    private var videoOverlay: some View {
        ZStack {
            if !isPlaying {
                // Play button — shown when paused / not yet started
                Circle()
                    .fill(.black.opacity(0.55))
                    .frame(width: 64, height: 64)
                Image(systemName: isVideoLoading ? "ellipsis" : "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(x: isVideoLoading ? 0 : 3)
            }

            VStack {
                Spacer()
                VStack(spacing: 4) {
                    // Seek bar
                    if videoDurationSecs > 0 {
                        GeometryReader { bar in
                            let progress = videoDurationSecs > 0 ? CGFloat(currentTime / videoDurationSecs) : 0
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.3)).frame(height: 3)
                                Capsule().fill(.white).frame(width: bar.size.width * progress, height: 3)
                                Circle().fill(.white).frame(width: 12, height: 12)
                                    .offset(x: bar.size.width * progress - 6)
                            }
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    isSeeking = true
                                    let ratio = max(0, min(1, val.location.x / bar.size.width))
                                    currentTime = ratio * videoDurationSecs
                                    player?.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600),
                                                 toleranceBefore: .zero, toleranceAfter: .zero)
                                }
                                .onEnded { _ in
                                    isSeeking = false
                                    if isPlaying { player?.play() }
                                }
                            )
                        }
                        .frame(height: 12)
                        .padding(.horizontal, 12)
                    }

                    HStack {
                        Text(formatDuration(currentTime))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(.leading, 12)
                        Spacer()
                        if videoDurationSecs > 0 {
                            Text(formatDuration(videoDurationSecs))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.6), in: Capsule())
                        }
                        Image(systemName: isPlaying ? "pause.fill" : "video.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(.trailing, 12)
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPlaying)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var livePhotoOverlay: some View {
        ZStack {
            // Native-style Live Photo badge — top left, always visible
            VStack {
                HStack {
                    Image(systemName: isLivePhotoLoading ? "ellipsis" : "livephoto")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                        .padding(.leading, 14)
                        .padding(.top, 14)
                    Spacer()
                }
                Spacer()
            }

            // Loading indicator — shown while live photo is being fetched
            if isLivePhotoLoading {
                Circle()
                    .fill(.black.opacity(0.45))
                    .frame(width: 56, height: 56)
                ProgressView().tint(.white).scaleEffect(1.2)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLivePhotoPlaying)
        .animation(.easeInOut(duration: 0.2), value: isLivePhotoLoading)
    }

    // MARK: - Gestures

    // Single DragGesture that routes to pan (zoomed) or swipe (normal)
    private var combinedDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isZoomed {
                    zoomOffset = CGSize(
                        width: lastZoomOffset.width + value.translation.width,
                        height: lastZoomOffset.height + value.translation.height
                    )
                } else {
                    isDragging = true
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                        offset = value.translation
                    }
                }
            }
            .onEnded { value in
                if isZoomed {
                    lastZoomOffset = zoomOffset
                } else {
                    isDragging = false
                    let threshold: CGFloat = 110
                    let w = value.translation.width
                    let h = value.translation.height
                    if w > threshold || value.predictedEndTranslation.width > 300 {
                        flyOut(.keep)
                    } else if w < -threshold || value.predictedEndTranslation.width < -300 {
                        flyOut(.delete)
                    } else if h < -threshold || value.predictedEndTranslation.height < -300 {
                        flyOut(.skip)
                    } else {
                        snapBack()
                    }
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1.0), 4.0)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1.05 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        scale = 1.0
                        zoomOffset = .zero
                        lastZoomOffset = .zero
                    }
                }
            }
    }

    private func flyOut(_ direction: SwipeDirection) {
        let target: CGSize
        switch direction {
        case .keep:   target = CGSize(width: 700, height: offset.height * 2)
        case .delete: target = CGSize(width: -700, height: offset.height * 2)
        case .skip:   target = CGSize(width: offset.width, height: -900)
        case .none:   return
        }
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.7)) {
            offset = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onSwipe(direction)
        }
    }

    private func snapBack() {
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.7)) {
            offset = .zero
        }
    }

    // MARK: - Badges

    private var keepBadge: some View {
        VStack {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .black))
                    Text(lm.s.keepBadge).font(.system(size: 15, weight: .black, design: .rounded)).tracking(1.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color(.systemGreen)).shadow(color: Color(.systemGreen).opacity(0.5), radius: 8))
                .rotationEffect(.degrees(-12))
                .padding(.leading, 20).padding(.top, 32)
                Spacer()
            }
            Spacer()
        }
    }

    private var deleteBadge: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill").font(.system(size: 14, weight: .black))
                    Text(lm.s.deleteBadge).font(.system(size: 15, weight: .black, design: .rounded)).tracking(1.5)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color(.systemRed)).shadow(color: Color(.systemRed).opacity(0.5), radius: 8))
                .rotationEffect(.degrees(12))
                .padding(.trailing, 20).padding(.top, 32)
            }
            Spacer()
        }
    }

    private var skipBadge: some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill").font(.system(size: 14, weight: .black))
                Text(lm.s.laterBadge).font(.system(size: 15, weight: .black, design: .rounded)).tracking(1.5)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color(.systemOrange)).shadow(color: Color(.systemOrange).opacity(0.5), radius: 8))
            .padding(.top, 36)
            Spacer()
        }
    }

    private var videoSeekBarHeight: CGFloat { isVideo && videoDurationSecs > 0 ? 50 : 0 }

    private var shareButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    loadAndShare()
                } label: {
                    Image(systemName: isLoadingShare ? "ellipsis" : "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(.trailing, 12)
                .padding(.bottom, 58 + videoSeekBarHeight)
            }
        }
    }

    private func loadAndShare() {
        guard !isLoadingShare else { return }
        isLoadingShare = true
        Task {
            let items = await vm.shareItems(for: photoID)
            shareItems = items
            isLoadingShare = false
            if !items.isEmpty { showShareSheet = true }
        }
    }

    private var favoriteButton: some View {
        let isFav = vm.favoriteIDs.contains(photoID)
        return VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    Task { await vm.toggleFavorite(for: photoID) }
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isFav ? Color.pink : Color.white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.45), in: Circle())
                        .shadow(color: isFav ? Color.pink.opacity(0.5) : .clear, radius: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFav)
                }
                .padding(.trailing, 12)
                .padding(.bottom, 12 + videoSeekBarHeight)
            }
        }
    }
}

// UIViewRepresentable wrapping PHLivePhotoView — gesture-safe inline playback
private struct LivePhotoPlayerView: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    let isPlaying: Bool

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.livePhoto = livePhoto
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.isMuted = false
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
        if isPlaying {
            uiView.startPlayback(with: .full)
        } else {
            uiView.stopPlayback()
        }
    }
}

// UIViewRepresentable wrapping AVPlayerLayer — no gesture conflicts with swipe
private struct InlineVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
    }

    class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
