import SwiftUI
import AVKit
import Photos

struct VideoPlayerSheet: View {
    let photoID: String
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(\.dismiss) var dismiss

    @State private var player: AVPlayer? = nil
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onDisappear { player.pause() }
            } else if failed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Video yüklenemedi")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                ProgressView().tint(.white).scaleEffect(1.4)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
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
                Spacer()
            }
        }
        .onAppear { loadVideo() }
    }

    private func loadVideo() {
        guard let asset = vm.asset(for: photoID) else {
            failed = true; isLoading = false; return
        }

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic   // başlangıç için mevcut en iyi kaliteyi kullan
        options.version = .current
        options.progressHandler = { progress, _, _, _ in
            // iCloud indirme ilerliyor — loading spinner zaten gösteriliyor
            _ = progress
        }

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
            DispatchQueue.main.async {
                guard let avAsset else {
                    self.failed = true
                    self.isLoading = false
                    return
                }
                let item = AVPlayerItem(asset: avAsset)
                self.player = AVPlayer(playerItem: item)
                self.player?.play()
                self.isLoading = false
            }
        }
    }
}
