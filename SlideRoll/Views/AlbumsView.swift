import SwiftUI
import Photos
import UIKit

// MARK: - Model

enum AlbumKind: String {
    case smart  // iPhone'un otomatik oluşturduğu (Favoriler, Live Photos, vb.)
    case shared // Paylaşılan albümler
    case user   // Kullanıcının oluşturduğu albümler
}

struct AlbumItem: Identifiable {
    let id: String
    let collection: PHAssetCollection
    let title: String
    let photoCount: Int
    let videoCount: Int
    var kind: AlbumKind = .user
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

// MARK: - Strings+SmartAlbums (Photos dependency stays in this file)

extension Strings {
    func smartAlbumTitle(_ subtype: PHAssetCollectionSubtype) -> String? {
        switch subtype {
        case .smartAlbumSelfPortraits:  return smartSelfies
        case .smartAlbumScreenshots:    return smartScreenshots
        case .smartAlbumFavorites:      return smartFavorites
        case .smartAlbumVideos:         return smartVideos
        case .smartAlbumBursts:         return smartBursts
        case .smartAlbumPanoramas:      return smartPanoramas
        case .smartAlbumSlomoVideos:    return smartSlowMotion
        case .smartAlbumTimelapses:     return smartTimelapse
        case .smartAlbumAnimated:       return smartAnimated
        case .smartAlbumLivePhotos:     return smartLivePhotos
        case .smartAlbumDepthEffect:    return smartPortrait
        case .smartAlbumRecentlyAdded:  return smartRecentlyAdded
        default:                        return nil
        }
    }
}

// MARK: - ViewModel

@Observable
final class AlbumsViewModel {
    var albums: [AlbumItem] = []
    var isLoading = true
    private let imageManager = PHCachingImageManager()

    func load(strings: Strings) async {
        var items: [AlbumItem] = []

        // --- Sistem albümleri (kind: .smart) — Recents/UserLibrary kasıtlı hariç ---
        let smartTypes: [PHAssetCollectionSubtype] = [
            .smartAlbumSelfPortraits, .smartAlbumScreenshots,
            .smartAlbumFavorites, .smartAlbumVideos, .smartAlbumBursts,
            .smartAlbumPanoramas, .smartAlbumSlomoVideos, .smartAlbumTimelapses,
            .smartAlbumAnimated, .smartAlbumLivePhotos, .smartAlbumDepthEffect,
            .smartAlbumRecentlyAdded
        ]
        for subtype in smartTypes {
            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil)
                .enumerateObjects { col, _, _ in
                    let all = PHAsset.fetchAssets(in: col, options: nil)
                    guard all.count > 0 else { return }
                    let vo = PHFetchOptions()
                    vo.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                    let vids = PHAsset.fetchAssets(in: col, options: vo).count
                    let title = strings.smartAlbumTitle(subtype) ?? col.localizedTitle ?? ""
                    items.append(AlbumItem(id: col.localIdentifier, collection: col,
                                           title: title,
                                           photoCount: all.count - vids, videoCount: vids,
                                           kind: .smart))
                }
        }

        // --- Paylaşılan albümler (kind: .shared) ---
        let so = PHFetchOptions()
        so.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: so)
            .enumerateObjects { col, _, _ in
                let all = PHAsset.fetchAssets(in: col, options: nil)
                guard all.count > 0 else { return }
                let vo = PHFetchOptions()
                vo.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                let vids = PHAsset.fetchAssets(in: col, options: vo).count
                items.append(AlbumItem(id: col.localIdentifier, collection: col,
                                       title: col.localizedTitle ?? "",
                                       photoCount: all.count - vids, videoCount: vids,
                                       kind: .shared))
            }

        // --- Kullanıcı albümleri (kind: .user) ---
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
                                       photoCount: all.count - vids, videoCount: vids,
                                       kind: .user))
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
    @State private var showPicker = false

    @AppStorage("pinnedAlbumIDs") private var pinnedRaw: String = ""

    private let tileHeights: [CGFloat] = [205, 155, 180, 145, 220, 165, 195, 150, 210, 170, 185, 140]

    private var pinnedIDs: Set<String> {
        Set(pinnedRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private var displayedAlbums: [(offset: Int, element: AlbumItem)] {
        Array(albumsVM.albums.enumerated()).filter { pinnedIDs.contains($0.element.id) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if pinnedIDs.isEmpty {
                emptyState
            } else if albumsVM.isLoading {
                skeletonView
            } else {
                albumGrid
            }
        }
        .toolbar {
            if !pinnedIDs.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPicker = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            AlbumPickerSheet(albums: albumsVM.albums,
                             isLoading: albumsVM.isLoading,
                             pinnedRaw: $pinnedRaw)
                .environment(lm)
        }
        .task { await albumsVM.load(strings: lm.s) }
    }

    // MARK: Grid

    private var albumGrid: some View {
        ScrollView(showsIndicators: false) {
            MasonryLayout(columns: 3, spacing: 5) {
                ForEach(displayedAlbums, id: \.element.id) { pair in
                    NavigationLink(destination: AlbumDetailView(
                        collection: pair.element.collection, title: pair.element.title)) {
                        AlbumTile(
                            album: pair.element,
                            height: tileHeights[pair.offset % tileHeights.count],
                            animationDelay: Double(pair.offset) * 0.05
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

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 80, height: 80)
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            VStack(spacing: 10) {
                Text(lm.s.albumsEmptyTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(lm.s.albumsEmptyDesc)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                showPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text(lm.s.albumsAddButton)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 15)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .opacity(albumsVM.isLoading ? 0.5 : 1)
            .overlay(alignment: .trailing) {
                if albumsVM.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                        .offset(x: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 44)
    }

    // MARK: Skeleton

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

// MARK: - Album Picker Sheet

struct AlbumPickerSheet: View {
    let albums: [AlbumItem]
    let isLoading: Bool
    @Binding var pinnedRaw: String
    @Environment(LanguageManager.self) var lm
    @Environment(\.dismiss) private var dismiss

    private var pinnedIDs: Set<String> {
        Set(pinnedRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private var smartAlbums:  [AlbumItem] { albums.filter { $0.kind == .smart  } }
    private var sharedAlbums: [AlbumItem] { albums.filter { $0.kind == .shared } }
    private var userAlbums:   [AlbumItem] { albums.filter { $0.kind == .user   } }

    private func toggle(_ id: String) {
        var set = pinnedIDs
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pinnedRaw = set.joined(separator: ",")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.07).ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 14) {
                        ProgressView().tint(.white)
                        Text(lm.s.albumsLoading)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !smartAlbums.isEmpty {
                            Section {
                                ForEach(smartAlbums) { album in
                                    albumRow(album)
                                }
                            } header: {
                                pickerSectionHeader(lm.s.albumsSectionSmart,
                                                    icon: "iphone",
                                                    count: smartAlbums.filter { pinnedIDs.contains($0.id) }.count,
                                                    total: smartAlbums.count)
                            }
                        }

                        if !sharedAlbums.isEmpty {
                            Section {
                                ForEach(sharedAlbums) { album in
                                    albumRow(album)
                                }
                            } header: {
                                pickerSectionHeader(lm.s.albumsSectionShared,
                                                    icon: "person.2",
                                                    count: sharedAlbums.filter { pinnedIDs.contains($0.id) }.count,
                                                    total: sharedAlbums.count)
                            }
                        }

                        if !userAlbums.isEmpty {
                            Section {
                                ForEach(userAlbums) { album in
                                    albumRow(album)
                                }
                            } header: {
                                pickerSectionHeader(lm.s.albumsSectionUser,
                                                    icon: "rectangle.stack",
                                                    count: userAlbums.filter { pinnedIDs.contains($0.id) }.count,
                                                    total: userAlbums.count)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(lm.s.albumsSelectedCount(pinnedIDs.count))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lm.s.done) { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .topBarLeading) {
                    let allSelected = pinnedIDs.count == albums.count
                    Button(allSelected ? lm.s.albumsClear : lm.s.selectAll) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if allSelected {
                                pinnedRaw = ""
                            } else {
                                pinnedRaw = albums.map(\.id).joined(separator: ",")
                            }
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(allSelected ? .white.opacity(0.45) : Theme.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func albumRow(_ album: AlbumItem) -> some View {
        Button { toggle(album.id) } label: {
            AlbumPickerRow(album: album, isPinned: pinnedIDs.contains(album.id))
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(white: 0.12))
        .listRowSeparatorTint(Color.white.opacity(0.07))
    }

    @ViewBuilder
    private func pickerSectionHeader(_ title: String, icon: String, count: Int, total: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            if count > 0 {
                Text("\(count)/\(total)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.accent.opacity(0.8))
            }
        }
        .textCase(nil)
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
    }
}

// MARK: - Album Picker Row

struct AlbumPickerRow: View {
    let album: AlbumItem
    let isPinned: Bool
    @Environment(LanguageManager.self) var lm

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                album.dominantColor
                if let thumb = album.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(lm.s.statItemCount(album.total))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(isPinned ? Theme.accent : Color.white.opacity(0.08))
                    .frame(width: 28, height: 28)
                if isPinned {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isPinned)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
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
