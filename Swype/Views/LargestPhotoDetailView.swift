import SwiftUI
import AVKit
import Photos

struct LargestPhotoDetailView: View {
    let photoID: String
    let bytes: Int64
    let date: Date
    var isVideo: Bool = false

    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) var dismiss

    @State private var image: UIImage?
    @State private var decision: PhotoDecision? = nil
    @State private var animating = false

    // Video
    @State private var player: AVPlayer?
    @State private var isVideoLoading = false
    @State private var videoFailed = false
    @State private var isPlaying = false
    @State private var isMuted = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    @State private var timeObserver: Any?

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
                topBar
                Spacer()
                mediaArea
                Spacer()

                if let dec = decision {
                    decisionBadge(dec)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 12)
                }

                actionButtons
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: decision)
        .task {
            image = await vm.loadImage(for: photoID, targetSize: CGSize(width: 1000, height: 1000))
            for group in vm.monthGroups {
                if let d = group.decisions[photoID] { decision = d; break }
            }
            if isVideo { loadVideo() }
        }
        .onDisappear {
            player?.pause()
            if let obs = timeObserver { player?.removeTimeObserver(obs) }
            player = nil
            timeObserver = nil
        }
    }

    // MARK: - Top Bar

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
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: isVideo ? "video.fill" : "photo.fill")
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
    }

    // MARK: - Media Area

    @ViewBuilder
    private var mediaArea: some View {
        VStack(spacing: 12) {
            ZStack {
                if let p = player {
                    InlineVideoPlayer(player: p)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onTapGesture { togglePlay(p) }
                } else if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)

                    if isVideo {
                        if isVideoLoading {
                            ProgressView().tint(.white).scaleEffect(1.4)
                        } else if videoFailed {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(lm.s.videoLoadError)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        } else {
                            Circle()
                                .fill(.black.opacity(0.5))
                                .frame(width: 68, height: 68)
                            Image(systemName: "play.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                                .offset(x: 3)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.06))
                        .overlay(ProgressView().tint(.white))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .scaleEffect(animating ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: animating)

            // Video controls — only shown when player is ready
            if player != nil && isVideo {
                videoControls
            }
        }
        .padding(.horizontal, 16)
    }

    private var videoControls: some View {
        VStack(spacing: 6) {
            // Progress + times in one row
            HStack(spacing: 8) {
                Text(formatTime(currentTime))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 30, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { val in
                            currentTime = val
                            isSeeking = true
                            player?.seek(to: CMTime(seconds: val, preferredTimescale: 600)) { _ in
                                isSeeking = false
                            }
                        }
                    ),
                    in: 0...(duration > 0 ? duration : 1)
                )
                .tint(.white)

                Text(formatTime(duration))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 30, alignment: .trailing)
            }

            // Buttons row
            ZStack {
                HStack(spacing: 28) {
                    Button {
                        player?.seek(to: CMTime(seconds: max(0, currentTime - 10), preferredTimescale: 600))
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Button { if let p = player { togglePlay(p) } } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.15), in: Circle())
                    }

                    Button {
                        player?.seek(to: CMTime(seconds: min(duration, currentTime + 10), preferredTimescale: 600))
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)

                HStack {
                    Spacer()
                    Button {
                        isMuted.toggle()
                        player?.isMuted = isMuted
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    // MARK: - Action Buttons

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

    // MARK: - Video Loading

    private func loadVideo() {
        guard let asset = vm.asset(for: photoID) else { videoFailed = true; return }
        isVideoLoading = true

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        options.version = .current

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            DispatchQueue.main.async {
                guard let avAsset else { self.videoFailed = true; self.isVideoLoading = false; return }
                let item = AVPlayerItem(asset: avAsset)
                let p = AVPlayer(playerItem: item)
                self.player = p
                self.isVideoLoading = false

                // Duration
                let dur = avAsset.duration.seconds
                self.duration = dur.isNaN ? 0 : dur

                // Periodic time observer
                let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
                self.timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                    if !self.isSeeking {
                        self.currentTime = time.seconds.isNaN ? 0 : time.seconds
                    }
                    self.isPlaying = p.timeControlStatus == .playing
                }

                // Loop
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: p.currentItem, queue: .main) { _ in
                        p.seek(to: .zero)
                        p.play()
                }

                p.play()
                self.isPlaying = true
            }
        }
    }

    private func togglePlay(_ p: AVPlayer) {
        if p.timeControlStatus == .playing {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }

    // MARK: - Helpers

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
        .background(Capsule().fill((isDelete ? Theme.red : Theme.green).opacity(0.15)))
    }

    private func formatTime(_ s: Double) -> String {
        let t = Int(max(0, s))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func formatBytes(_ b: Int64) -> String {
        let gb = Double(b) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(b) / 1_048_576)
    }
}

// AVPlayerLayer tabanlı video görüntüleyici — SwiftUI VideoPlayer wrapper sorunlarından kaçınır
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
