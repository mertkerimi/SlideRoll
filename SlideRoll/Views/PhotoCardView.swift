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
    @Binding var externalFlyout: SwipeDirection?

    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    private let netMonitor = NetworkMonitor.shared
    @State private var offset: CGSize = .zero
    @State private var image: UIImage?
    @State private var isDragging = false
    @State private var isVideo = false
    @State private var isInCloud = false
    @State private var isDownloadingFromCloud = false
    @State private var downloadProgress: Double = 0
    @State private var imageDownloadFailed = false
    @State private var videoLoadFailed = false
    @State private var livePhotoLoadFailed = false
    @State private var player: AVPlayer?
    @State private var isVideoLoading = false
    @State private var isPlaying = false
    @State private var isMuted = false
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
    @State private var cardSize: CGSize = .zero
    private var isZoomed: Bool { scale > 1.01 }

    // Keeps the pan within the extra room the current zoom level actually
    // provides — without this, dragging far enough pulls the (still-clipped)
    // image completely out of the card, leaving a blank card behind it.
    private func clampedZoomOffset(_ offset: CGSize) -> CGSize {
        let maxX = max(0, (scale - 1) * cardSize.width / 2)
        let maxY = max(0, (scale - 1) * cardSize.height / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private let lightImpact  = UIImpactFeedbackGenerator(style: .light)
    private let heavyImpact  = UIImpactFeedbackGenerator(style: .heavy)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

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
                // Zoom scale/pan apply only to the photo content, not the share/
                // favorite/undo button overlays below — those must stay fixed in
                // the card's own coordinate space instead of panning/scaling
                // along with the image underneath them.
                photoLayer(size: geo.size)
                    .scaleEffect(isZoomed ? scale : 1.0)
                    .offset(isZoomed ? zoomOffset : .zero)
                swipeColorOverlay
                keepBadge.opacity(keepOpacity)
                deleteBadge.opacity(deleteOpacity)
                skipBadge.opacity(skipOpacity)
                if isVideo { videoOverlay }
                if isLivePhoto { livePhotoOverlay }
                if isInCloud || imageDownloadFailed { iCloudBadge }
                shareButton
                favoriteButton
                if isVideo || isLivePhoto {
                    mediaUndoButton
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .offset(isZoomed ? .zero : offset)
            .rotationEffect(.degrees(rotation))
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
            .onAppear { cardSize = geo.size }
            .onChange(of: geo.size) { _, newSize in cardSize = newSize }
        }
        .task {
            lightImpact.prepare()
            heavyImpact.prepare()
            mediumImpact.prepare()
            isVideo = vm.isVideo(for: photoID)
            isLivePhoto = vm.isLivePhoto(for: photoID)
            isInCloud = await vm.isInCloud(for: photoID)
            // Phase 1: show thumbnail immediately (prevents blank card)
            image = await vm.loadThumbnail(for: photoID)

            // Phase 2: upgrade to full quality. `isInCloud` only inspects a tiny
            // local thumbnail request, so it can under-report — skip the network
            // attempt entirely only when we're confident (isInCloud true) AND
            // offline; otherwise always attempt, and treat a timeout as failure
            // regardless of what isInCloud said.
            if isInCloud && !netMonitor.isConnected {
                imageDownloadFailed = true
            } else {
                downloadProgress = 0
                isDownloadingFromCloud = isInCloud
                if let full = await vm.loadImage(for: photoID, targetSize: CGSize(width: 700, height: 900), onProgress: { p in
                    downloadProgress = p
                }, onNeedsCloudFetch: {
                    if !netMonitor.isConnected { imageDownloadFailed = true }
                }) {
                    image = full
                }
                isDownloadingFromCloud = false
            }

            if isLivePhoto {
                if isInCloud && !netMonitor.isConnected {
                    livePhotoLoadFailed = true
                } else {
                    downloadProgress = 0
                    isDownloadingFromCloud = isInCloud
                    let lp = await vm.loadLivePhoto(for: photoID, targetSize: CGSize(width: 700, height: 900), onProgress: { p in
                        downloadProgress = p
                    })
                    livePhoto = lp
                    isLivePhotoPlaying = true
                    isDownloadingFromCloud = false
                    if lp == nil && isInCloud { livePhotoLoadFailed = true }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lm.s.a11yPhoto)
        .accessibilityHint(lm.s.a11ySwipeHint)
        .onChange(of: externalFlyout) { _, dir in
            guard let dir, dir != .none else { return }
            flyOut(dir, fromButton: true)
        }
        .onChange(of: dragDirection) { _, newDir in
            switch newDir {
            case .keep:   lightImpact.impactOccurred()
            case .delete: heavyImpact.impactOccurred()
            case .skip:   mediumImpact.impactOccurred()
            case .none:   break
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
        videoLoadFailed = false
        if isInCloud && !netMonitor.isConnected {
            videoLoadFailed = true
            return
        }
        isVideoLoading = true
        if isInCloud { downloadProgress = 0; isDownloadingFromCloud = true }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        options.progressHandler = { progress, _, _, _ in
            DispatchQueue.main.async { self.downloadProgress = progress }
        }
        var resumed = false
        let requestID = PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            DispatchQueue.main.async {
                guard !resumed else { return }
                resumed = true
                self.isDownloadingFromCloud = false
                guard let avAsset else { self.isVideoLoading = false; self.videoLoadFailed = true; return }
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try? AVAudioSession.sharedInstance().setActive(true)
                let p = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                p.play()
                self.player = p
                self.isPlaying = true
                self.isVideoLoading = false
                self.videoDurationSecs = CMTimeGetSeconds(avAsset.duration)
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

        // 15s timeout — mirrors the live photo / full-res image fallbacks so a
        // stalled iCloud video download surfaces a clear failure instead of an
        // indefinite spinner.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            guard !resumed else { return }
            resumed = true
            PHImageManager.default().cancelImageRequest(requestID)
            self.isDownloadingFromCloud = false
            self.isVideoLoading = false
            self.videoLoadFailed = true
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
        livePhotoLoadFailed = false
        if isInCloud && !netMonitor.isConnected {
            livePhotoLoadFailed = true
            return
        }
        isLivePhotoLoading = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        if isInCloud { downloadProgress = 0; isDownloadingFromCloud = true }
        Task {
            let lp = await vm.loadLivePhoto(for: photoID, targetSize: CGSize(width: 700, height: 900), onProgress: { p in
                downloadProgress = p
            })
            livePhoto = lp
            isLivePhotoPlaying = true
            isLivePhotoLoading = false
            if lp == nil { livePhotoLoadFailed = true }
            isDownloadingFromCloud = false
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
                Button {
                    retryImageDownload()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: imageDownloadFailed ? "wifi.slash" : (isVideo ? "video" : "photo"))
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.textTertiary)
                        if imageDownloadFailed {
                            Text(lm.s.tapToRetry)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textTertiary)
                        } else if isInCloud && isDownloadingFromCloud {
                            CloudDownloadIndicator(progress: downloadProgress)
                        } else {
                            ProgressView().tint(Theme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!imageDownloadFailed)
            }
        }
    }

    private var iCloudBadge: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    retryImageDownload()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: imageDownloadFailed ? "wifi.slash" : (isDownloadingFromCloud ? "icloud.and.arrow.down" : "icloud"))
                            .font(.system(size: 11, weight: .semibold))
                        Text(imageDownloadFailed ? lm.s.noConnectionBadge : (isDownloadingFromCloud ? "\(Int(downloadProgress * 100))%" : "iCloud"))
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.55), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!imageDownloadFailed)
                .padding(.top, 14)
                .padding(.trailing, 14)
            }
            Spacer()
        }
    }

    private func retryImageDownload() {
        guard imageDownloadFailed, netMonitor.isConnected else { return }
        imageDownloadFailed = false
        Task {
            downloadProgress = 0
            isDownloadingFromCloud = true
            if let full = await vm.loadImage(for: photoID, targetSize: CGSize(width: 700, height: 900), onProgress: { p in
                downloadProgress = p
            }, onNeedsCloudFetch: {
                if !netMonitor.isConnected { imageDownloadFailed = true }
            }) {
                image = full
            }
            isDownloadingFromCloud = false
        }
    }

    private var videoOverlay: some View {
        ZStack {
            if !isPlaying {
                // Play button — shown when paused / not yet started
                Circle()
                    .fill(.black.opacity(0.55))
                    .frame(width: videoLoadFailed ? 100 : 64, height: videoLoadFailed ? 100 : 64)
                if videoLoadFailed {
                    VStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(lm.s.tapToRetry)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .frame(width: 84)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if isVideoLoading && isInCloud && isDownloadingFromCloud {
                    CloudDownloadIndicator(progress: downloadProgress)
                } else {
                    Image(systemName: isVideoLoading ? "ellipsis" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .offset(x: isVideoLoading ? 0 : 3)
                }
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
                        Button {
                            isMuted.toggle()
                            player?.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
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
            // Live Photo badge — top right, below iCloud badge when present
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: livePhotoLoadFailed ? "wifi.slash" : (isLivePhotoLoading ? "ellipsis" : "livephoto"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                        .padding(.trailing, 14)
                        .padding(.top, (isInCloud || imageDownloadFailed) ? 48 : 14)
                }
                Spacer()
            }

            // Loading / failure indicator — shown while live photo is being fetched, or if it couldn't be
            if isLivePhotoLoading || livePhotoLoadFailed {
                Circle()
                    .fill(.black.opacity(0.45))
                    .frame(width: livePhotoLoadFailed ? 90 : 56, height: livePhotoLoadFailed ? 90 : 56)
                if livePhotoLoadFailed {
                    VStack(spacing: 3) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(lm.s.tapToRetry)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .frame(width: 76)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if isInCloud && isDownloadingFromCloud {
                    CloudDownloadIndicator(progress: downloadProgress)
                } else {
                    ProgressView().tint(.white).scaleEffect(1.2)
                }
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
                    zoomOffset = clampedZoomOffset(CGSize(
                        width: lastZoomOffset.width + value.translation.width,
                        height: lastZoomOffset.height + value.translation.height
                    ))
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
                // Zooming back out shrinks how far the image can be panned —
                // pull any excess pan back in so content never ends up
                // clamped-out entirely, leaving blank space in the card.
                zoomOffset = clampedZoomOffset(zoomOffset)
                lastZoomOffset = zoomOffset
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

    private func flyOut(_ direction: SwipeDirection, fromButton: Bool = false) {
        let target: CGSize
        if fromButton {
            switch direction {
            case .keep:   target = CGSize(width: 220, height: 0)
            case .delete: target = CGSize(width: -220, height: 0)
            case .skip:   target = CGSize(width: 0, height: -260)
            case .none:   return
            }
        } else {
            switch direction {
            case .keep:   target = CGSize(width: 700, height: offset.height * 2)
            case .delete: target = CGSize(width: -700, height: offset.height * 2)
            case .skip:   target = CGSize(width: offset.width, height: -900)
            case .none:   return
            }
        }
        let animation: Animation = fromButton
            ? .spring(response: 0.58, dampingFraction: 0.92)
            : .interactiveSpring(response: 0.35, dampingFraction: 0.7)
        withAnimation(animation) { offset = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + (fromButton ? 0.40 : 0.35)) {
            onSwipe(direction)
        }
    }

    private func snapBack() {
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.7)) {
            offset = .zero
        }
    }

    // MARK: - Swipe Color Overlays

    private var swipeColorOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [.clear, Color.green.opacity(0.55)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .opacity(keepOpacity)

            LinearGradient(
                colors: [Color.red.opacity(0.55), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .opacity(deleteOpacity)
        }
        .allowsHitTesting(false)
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

    // Undo button — shown on video/live photo since tap is reserved for play/pause
    private var mediaUndoButton: some View {
        VStack {
            HStack {
                Button { onTapUndo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .padding(.leading, 14)
                .padding(.top, 14)
                Spacer()
            }
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

// Circular ring showing iCloud download progress, with a percentage label in the center
private struct CloudDownloadIndicator: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.15), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: 44, height: 44)
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
