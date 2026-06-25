import SwiftUI
import Photos
import UIKit

// MARK: - Model

struct AlbumItem: Identifiable {
    let id: String
    let collection: PHAssetCollection
    let title: String
    let photoCount: Int
    let videoCount: Int
    var thumbnail: UIImage?
    var dominantColor: Color = Color(white: 0.18)
    var reviewed: Int = 0
    var deleted: Int = 0
    var total: Int   { photoCount + videoCount }
    var pending: Int { total - reviewed }
    var progress: Double { total > 0 ? Double(reviewed) / Double(total) : 0 }
}

extension UIImage {
    func dominantColor() -> Color {
        guard let resized = resized(to: CGSize(width: 16, height: 16)),
              let cgImg = resized.cgImage else { return Color(white: 0.18) }
        let w = cgImg.width, h = cgImg.height
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return Color(white: 0.18) }
        ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return Color(white: 0.18) }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        let count = w * h
        let ptr = data.bindMemory(to: UInt8.self, capacity: count * 4)
        for i in 0..<count {
            r += CGFloat(ptr[i*4]); g += CGFloat(ptr[i*4+1]); b += CGFloat(ptr[i*4+2])
        }
        let f = CGFloat(count) * 255
        return Color(red: min(r/f*0.8,1), green: min(g/f*0.8,1), blue: min(b/f*0.8,1))
    }
    private func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        draw(in: CGRect(origin: .zero, size: size))
        let r = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return r
    }
}

// MARK: - ViewModel

@Observable
final class AlbumsViewModel {
    var albums: [AlbumItem] = []
    var isLoading = true
    private let imageManager = PHCachingImageManager()

    func load() async {
        var items: [AlbumItem] = []
        let smartTypes: [PHAssetCollectionSubtype] = [
            .smartAlbumUserLibrary, .smartAlbumSelfPortraits, .smartAlbumScreenshots,
            .smartAlbumFavorites, .smartAlbumVideos, .smartAlbumBursts,
            .smartAlbumPanoramas, .smartAlbumSlomoVideos, .smartAlbumTimelapses, .smartAlbumAnimated
        ]
        for subtype in smartTypes {
            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
                .enumerateObjects { col, _, _ in
                    let all = PHAsset.fetchAssets(in: col, options: nil)
                    guard all.count > 0 else { return }
                    let vo = PHFetchOptions()
                    vo.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                    let vids = PHAsset.fetchAssets(in: col, options: vo).count
                    items.append(AlbumItem(id: col.localIdentifier, collection: col,
                                           title: col.localizedTitle ?? "",
                                           photoCount: all.count - vids, videoCount: vids))
                }
        }
        let fo = PHFetchOptions()
        fo.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fo)
            .enumerateObjects { col, _, _ in
                let all = PHAsset.fetchAssets(in: col, options: nil)
                guard all.count > 0 else { return }
                let vo = PHFetchOptions()
                vo.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                let vids = PHAsset.fetchAssets(in: col, options: vo).count
                items.append(AlbumItem(id: col.localIdentifier, collection: col,
                                       title: col.localizedTitle ?? "",
                                       photoCount: all.count - vids, videoCount: vids))
            }
        // Show grid immediately with color placeholders — no waiting for thumbnails
        await MainActor.run { self.albums = items; self.isLoading = false }

        // Load thumbnails progressively in background
        for i in items.indices {
            if let asset = portraitAsset(in: items[i].collection) {
                let thumb = await fetchThumb(asset)
                if let thumb {
                    items[i].thumbnail = thumb
                    items[i].dominantColor = thumb.dominantColor()
                }
                let snapshot = items[i]
                await MainActor.run {
                    if i < self.albums.count { self.albums[i] = snapshot }
                }
            }
        }
    }

    private func portraitAsset(in collection: PHAssetCollection) -> PHAsset? {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(in: collection, options: opts)
        var found: PHAsset? = nil
        result.enumerateObjects { asset, _, stop in
            if asset.pixelHeight > asset.pixelWidth { found = asset; stop.pointee = true }
        }
        return found ?? result.firstObject ?? PHAsset.fetchAssets(in: collection, options: nil).lastObject
    }

    private func fetchThumb(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic; opts.resizeMode = .fast
            opts.isNetworkAccessAllowed = true; opts.isSynchronous = false
            var done = false
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 400, height: 600),
                                      contentMode: .aspectFill, options: opts) { img, info in
                let deg = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !deg && !done { done = true; cont.resume(returning: img) }
            }
        }
    }
}

// MARK: - Masonry Layout (Layout protocol — mathematically precise, zero overlap)

struct MasonryLayout: Layout {
    var columns: Int = 3
    var spacing: CGFloat = 5

    struct CacheData {
        var positions: [(col: Int, y: CGFloat)] = []
        var totalHeight: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> CacheData { CacheData() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0 else { return .zero }
        let (_, totalH) = layout(subviews: subviews, width: width)
        return CGSize(width: width, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        let colW = columnWidth(total: bounds.width)
        let (positions, _) = layout(subviews: subviews, width: bounds.width)
        for (i, subview) in subviews.enumerated() {
            guard i < positions.count else { continue }
            let pos = positions[i]
            let x = bounds.minX + CGFloat(pos.col) * (colW + spacing)
            subview.place(at: CGPoint(x: x, y: bounds.minY + pos.y),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: colW, height: nil))
        }
    }

    private func columnWidth(total: CGFloat) -> CGFloat {
        (total - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (positions: [(col: Int, y: CGFloat)], height: CGFloat) {
        let colW = columnWidth(total: width)
        var heights = [CGFloat](repeating: 0, count: columns)
        var positions: [(col: Int, y: CGFloat)] = []
        for subview in subviews {
            let col = heights.indices.min(by: { heights[$0] < heights[$1] }) ?? 0
            let h = subview.sizeThatFits(ProposedViewSize(width: colW, height: nil)).height
            positions.append((col: col, y: heights[col]))
            heights[col] += h + spacing
        }
        return (positions, (heights.max() ?? 0) - spacing)
    }
}

// MARK: - Shimmer

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(0, phase - 0.25)),
                        .init(color: .white.opacity(0.10), location: phase),
                        .init(color: .clear, location: min(1, phase + 0.25))
                    ],
                    startPoint: UnitPoint(x: phase - 0.5, y: 0),
                    endPoint:   UnitPoint(x: phase + 0.5, y: 1)
                )
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

// MARK: - Albums View

struct AlbumsView: View {
    @Environment(LanguageManager.self) var lm
    @Environment(PhotoLibraryViewModel.self) var vm
    @State private var albumsVM = AlbumsViewModel()

    private let tileHeights: [CGFloat] = [205, 155, 180, 145, 220, 165, 195, 150, 210, 170, 185, 140]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if albumsVM.isLoading {
                skeletonView
            } else {
                ScrollView(showsIndicators: false) {
                    MasonryLayout(columns: 3, spacing: 5) {
                        ForEach(Array(albumsVM.albums.enumerated()), id: \.offset) { idx, album in
                            NavigationLink(destination: AlbumDetailView(
                                collection: album.collection, title: album.title)) {
                                AlbumTile(
                                    album: album,
                                    height: tileHeights[idx % tileHeights.count],
                                    animationDelay: Double(idx) * 0.05
                                )
                            }
                            .buttonStyle(AlbumTilePress())
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
            }
        }
        .task { await albumsVM.load() }
    }

    private var skeletonView: some View {
        ScrollView(showsIndicators: false) {
            MasonryLayout(columns: 3, spacing: 5) {
                ForEach(0..<9, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.11))
                        .frame(height: tileHeights[idx % tileHeights.count])
                        .shimmer()
                }
            }
            .padding(.horizontal, 5)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Press Style

struct AlbumTilePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1, anchor: .center)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Album Tile

struct AlbumTile: View {
    let album: AlbumItem
    let height: CGFloat
    let animationDelay: Double

    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {

            // Background color fallback
            album.dominantColor

            // Photo
            if let thumb = album.thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .layoutPriority(-1)
            }

            // Gradient
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.88), location: 0),
                    .init(color: .black.opacity(0.45), location: 0.42),
                    .init(color: .clear,               location: 0.68)
                ],
                startPoint: .bottom, endPoint: .top
            )

            // Bottom info
            VStack(alignment: .leading, spacing: 3) {
                if album.reviewed > 0 {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.18)).frame(height: 2)
                            Capsule()
                                .fill(Theme.green)
                                .frame(width: g.size.width * album.progress, height: 2)
                        }
                    }
                    .frame(height: 2)
                }
                Text(album.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 9)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 0.6)
        )
        // Count badge — semi-transparent pill, no blur
        .overlay(alignment: .topLeading) {
            Text(album.total.formatted())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.52), in: Capsule())
                .padding(8)
        }
        // Heart badge — semi-transparent circle, no blur
        .overlay(alignment: .topTrailing) {
            Image(systemName: album.reviewed > 0 ? "heart.fill" : "heart")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(album.reviewed > 0 ? Theme.green : .white.opacity(0.85))
                .padding(6)
                .background(Color.black.opacity(0.52), in: Circle())
                .padding(8)
        }
        // Tile-local entrance animation: scale + fade, delay set by index
        .scaleEffect(appeared ? 1 : 0.82, anchor: .bottom)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(animationDelay)) {
                appeared = true
            }
        }
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
                        Group {
                            if let img = thumbnails[asset.localIdentifier] {
                                Image(uiImage: img).resizable().scaledToFill()
                            } else {
                                Rectangle().fill(Theme.surface)
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
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
        result.enumerateObjects { a, _, _ in list.append(a) }
        assets = list
    }

    private func loadThumb(_ asset: PHAsset) async {
        guard thumbnails[asset.localIdentifier] == nil else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .fastFormat; opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = true; opts.isSynchronous = false
        let img: UIImage? = await withCheckedContinuation { cont in
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200),
                                      contentMode: .aspectFill, options: opts) { img, _ in
                cont.resume(returning: img)
            }
        }
        if let img { thumbnails[asset.localIdentifier] = img }
    }
}
