import SwiftUI
import Photos
import UIKit

struct AlbumItem: Identifiable {
    let id: String
    let collection: PHAssetCollection
    let title: String
    let count: Int
    var thumbnail: UIImage?
}

@Observable
final class AlbumsViewModel {
    var albums: [AlbumItem] = []
    var isLoading = true

    private let imageManager = PHCachingImageManager()

    func load() async {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]

        var items: [AlbumItem] = []

        // Smart albums (Recents, Selfies, Screenshots, etc.)
        let smartTypes: [PHAssetCollectionSubtype] = [
            .smartAlbumUserLibrary, .smartAlbumSelfPortraits, .smartAlbumScreenshots,
            .smartAlbumFavorites, .smartAlbumVideos, .smartAlbumBursts, .smartAlbumPanoramas,
            .smartAlbumSlomoVideos, .smartAlbumTimelapses, .smartAlbumAnimated
        ]
        for subtype in smartTypes {
            let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
            result.enumerateObjects { col, _, _ in
                let assets = PHAsset.fetchAssets(in: col, options: nil)
                guard assets.count > 0 else { return }
                items.append(AlbumItem(id: col.localIdentifier, collection: col,
                                       title: col.localizedTitle ?? "", count: assets.count))
            }
        }

        // User albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
        userAlbums.enumerateObjects { col, _, _ in
            let assets = PHAsset.fetchAssets(in: col, options: nil)
            guard assets.count > 0 else { return }
            items.append(AlbumItem(id: col.localIdentifier, collection: col,
                                   title: col.localizedTitle ?? "", count: assets.count))
        }

        // Load thumbnails
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
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200),
                                      contentMode: .aspectFill, options: opts) { img, _ in
                cont.resume(returning: img)
            }
        }
    }
}

struct AlbumsView: View {
    @Environment(LanguageManager.self) var lm
    @State private var albumsVM = AlbumsViewModel()

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        Group {
            if albumsVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if albumsVM.albums.isEmpty {
                Text("No albums found")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(albumsVM.albums) { album in
                            NavigationLink(destination: AlbumDetailView(collection: album.collection, title: album.title)) {
                                AlbumCell(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .task { await albumsVM.load() }
    }
}

struct AlbumCell: View {
    let album: AlbumItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let thumb = album.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Theme.surface)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipped()

            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(album.count)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(10)
        }
        .clipped()
    }
}

struct AlbumDetailView: View {
    @Environment(LanguageManager.self) var lm
    let collection: PHAssetCollection
    let title: String

    @State private var assets: [PHAsset] = []
    @State private var thumbnails: [String: UIImage] = [:]
    private let imageManager = PHCachingImageManager()

    private let columns = [GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2), GridItem(.flexible(), spacing: 2)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    ZStack {
                        if let img = thumbnails[asset.localIdentifier] {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Rectangle()
                                .fill(Theme.surface)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
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
