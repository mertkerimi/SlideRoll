import SwiftUI
import Photos
import UIKit

struct AlbumItem: Identifiable {
    let id: String
    let collection: PHAssetCollection
    let title: String
    let photoCount: Int
    let videoCount: Int
    var thumbnail: UIImage?
    var reviewed: Int = 0
    var deleted: Int = 0

    var total: Int { photoCount + videoCount }
}

@Observable
final class AlbumsViewModel {
    var albums: [AlbumItem] = []
    var isLoading = true

    private let imageManager = PHCachingImageManager()

    func load() async {
        let smartTypes: [PHAssetCollectionSubtype] = [
            .smartAlbumUserLibrary, .smartAlbumSelfPortraits, .smartAlbumScreenshots,
            .smartAlbumFavorites, .smartAlbumVideos, .smartAlbumBursts, .smartAlbumPanoramas,
            .smartAlbumSlomoVideos, .smartAlbumTimelapses, .smartAlbumAnimated
        ]

        var items: [AlbumItem] = []

        for subtype in smartTypes {
            let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
            result.enumerateObjects { col, _, _ in
                let all   = PHAsset.fetchAssets(in: col, options: nil)
                guard all.count > 0 else { return }
                let opts = PHFetchOptions(); opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                let vids  = PHAsset.fetchAssets(in: col, options: opts).count
                items.append(AlbumItem(id: col.localIdentifier, collection: col,
                                       title: col.localizedTitle ?? "",
                                       photoCount: all.count - vids, videoCount: vids))
            }
        }

        let fetchOpts = PHFetchOptions()
        fetchOpts.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOpts)
        userAlbums.enumerateObjects { col, _, _ in
            let all = PHAsset.fetchAssets(in: col, options: nil)
            guard all.count > 0 else { return }
            let opts = PHFetchOptions(); opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            let vids = PHAsset.fetchAssets(in: col, options: opts).count
            items.append(AlbumItem(id: col.localIdentifier, collection: col,
                                   title: col.localizedTitle ?? "",
                                   photoCount: all.count - vids, videoCount: vids))
        }

        for i in items.indices {
            let assetFetch = PHAsset.fetchAssets(in: items[i].collection, options: nil)
            if let asset = assetFetch.lastObject {
                items[i].thumbnail = await fetchThumb(asset)
            }
        }

        await MainActor.run {
            self.albums = items
            self.isLoading = false
        }
    }

    private func fetchThumb(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .fastFormat
            opts.resizeMode = .fast
            opts.isNetworkAccessAllowed = true
            opts.isSynchronous = false
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 120, height: 120),
                                      contentMode: .aspectFill, options: opts) { img, _ in
                cont.resume(returning: img)
            }
        }
    }
}

struct AlbumsView: View {
    @Environment(LanguageManager.self) var lm
    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var albumsVM = AlbumsViewModel()

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if albumsVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if albumsVM.albums.isEmpty {
                Text("No albums found")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(albumsVM.albums) { album in
                            NavigationLink(destination: AlbumDetailView(collection: album.collection, title: album.title)) {
                                AlbumCard(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .task { await albumsVM.load() }
    }
}

struct AlbumCard: View {
    let album: AlbumItem
    @Environment(\.colorScheme) var colorScheme

    private var cardOpacity: Double { colorScheme == .dark ? 0.08 : 0.14 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(album.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if album.photoCount > 0 {
                            Label("\(album.photoCount) fotoğraf", systemImage: "photo")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        if album.videoCount > 0 {
                            Text("·").foregroundStyle(Theme.textTertiary)
                            Label("\(album.videoCount) video", systemImage: "video")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                Spacer()
                // Thumbnail
                if let thumb = album.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.surfaceHigh)
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(width: 52, height: 52)
                }
            }

            // Stat row
            HStack(spacing: 0) {
                statBlock(value: "\(album.reviewed)", label: "İncelendi", color: Theme.green)
                divider
                statBlock(value: "\(album.deleted)", label: "Silindi", color: Theme.red)
                divider
                statBlock(value: "\(album.total - album.reviewed)", label: "Bekliyor", color: Theme.orange)
                divider
                statBlock(value: "\(album.total)", label: "Toplam", color: Theme.accent)
            }

            // Progress bar (empty for now, will fill as user reviews)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceHigh).frame(height: 5)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.accent, Theme.accentEnd], startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: .infinity, maxHeight: 5)
                    .scaleEffect(x: 0, y: 1, anchor: .leading)
            }
            .frame(height: 5)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Theme.accent.opacity(cardOpacity), Theme.accent.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }

    private var divider: some View {
        Divider().background(Theme.border).frame(height: 32).padding(.horizontal, 12)
    }

    private func statBlock(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Album Detail

struct AlbumDetailView: View {
    @Environment(LanguageManager.self) var lm
    let collection: PHAssetCollection
    let title: String

    @State private var assets: [PHAsset] = []
    @State private var thumbnails: [String: UIImage] = [:]
    private let imageManager = PHCachingImageManager()

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    GeometryReader { geo in
                        ZStack {
                            if let img = thumbnails[asset.localIdentifier] {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.width)
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(Theme.surface)
                                    .frame(width: geo.size.width, height: geo.size.width)
                            }
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .task { await loadThumb(asset) }
                }
            }
            .padding(.bottom, 100)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { loadAssets() }
    }

    private func loadAssets() {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(in: collection, options: opts)
        var list: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in list.append(asset) }
        assets = list
    }

    private func loadThumb(_ asset: PHAsset) async {
        guard thumbnails[asset.localIdentifier] == nil else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .fastFormat
        opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = true
        opts.isSynchronous = false
        let img: UIImage? = await withCheckedContinuation { cont in
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200),
                                      contentMode: .aspectFill, options: opts) { img, _ in
                cont.resume(returning: img)
            }
        }
        if let img { thumbnails[asset.localIdentifier] = img }
    }
}
