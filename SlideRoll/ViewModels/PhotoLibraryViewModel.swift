import Foundation
import Photos
import SwiftUI
import WidgetKit

@Observable
@MainActor
class PhotoLibraryViewModel {
    var authStatus: PHAuthorizationStatus = .notDetermined
    var monthGroups: [MonthGroup] = []
    var isLoading = false
    var toDeleteIDs: [String] = []
    var favoriteIDs: Set<String> = []

    // Library stats
    var photoCount: Int = 0
    var videoCount: Int = 0
    var photoBytes: Int64 = 0
    var videoBytes: Int64 = 0
    var duplicateGroups: [[String]] = []
    var yearlyStorage: [(year: String, bytes: Int64)] = []
    var largestPhotos: [(id: String, bytes: Int64, date: Date)] = []
    var largestVideos: [(id: String, bytes: Int64, date: Date, duration: TimeInterval)] = []

    // Only count groups where all photos are still undecided
    var duplicateCount: Int {
        let decidedIDs = Set(monthGroups.flatMap { g in
            g.decisions.compactMap { id, d in d != .undecided ? id : nil }
        })
        return duplicateGroups.filter { group in
            group.filter { !decidedIDs.contains($0) }.count >= 2
        }.count
    }
    // Lifetime reviewed/total counts for the overall-progress UI. Permanently
    // deleting photos removes them from monthGroups entirely (they no longer
    // exist), which would otherwise make "reviewed" and "total" silently drop
    // by the same amount and erase past progress from view. totalDeletedCount
    // is a persisted, monotonically-increasing counter, so adding it back in
    // keeps both figures — and the percentage — stable across deletions.
    var lifetimeReviewedCount: Int {
        monthGroups.reduce(0) { $0 + $1.reviewed } + totalDeletedCount
    }
    var lifetimeTotalCount: Int {
        monthGroups.reduce(0) { $0 + $1.total } + totalDeletedCount
    }

    var statsLoading = false
    private var statsLoaded = false


    // Cumulative stats — persisted across sessions
    var totalDeletedCount: Int {
        get { UserDefaults.standard.integer(forKey: "TotalDeletedCount") }
        set { UserDefaults.standard.set(newValue, forKey: "TotalDeletedCount") }
    }

    // Duplicate groups the user chose to skip in "Olası Kopyalar", keyed by
    // their sorted-photoID list joined with ",". Persisted so a skip sticks
    // across app sessions instead of resurfacing the same group every time.
    var skippedDuplicateGroupKeys: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "SkippedDuplicateGroupKeys") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "SkippedDuplicateGroupKeys") }
    }

    var deletedCountByYear: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: "DeletedCountByYear") as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "DeletedCountByYear") }
    }

    var deletedCountByMonth: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: "DeletedCountByMonth") as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "DeletedCountByMonth") }
    }

    var deletedCountByAlbum: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: "DeletedCountByAlbum") as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "DeletedCountByAlbum") }
    }

    // Maps photoID → albumID so permanentlyDeleteTrash can credit the right album
    var photoAlbumMap: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "PhotoAlbumMap") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "PhotoAlbumMap") }
    }

    let imageManager = PHCachingImageManager()
    private let persistenceKey = "PhotoCleanerDecisions"
    private var allAssets: [String: PHAsset] = [:]

    private var savedDecisions: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: persistenceKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: persistenceKey) }
    }

    // MARK: - Daily Stats
    private static let sharedDefaults = UserDefaults(suiteName: "group.com.mertkerimi.slideroll") ?? .standard
    private static let dailyCountKey = "dailyDecisionCount"
    private static let dailyDateKey  = "dailyDecisionDate"

    // Stored property so @Observable fires whenever the streak changes,
    // even from calls originating in GlobalReviewView (behind a fullScreenCover).
    var todayDecisionCount: Int = 0

    private var todayString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    private func loadTodayCount() {
        let stored = Self.sharedDefaults.integer(forKey: Self.dailyCountKey)
        let storedDate = Self.sharedDefaults.string(forKey: Self.dailyDateKey)
        todayDecisionCount = (storedDate == todayString) ? stored : 0
    }

    private func incrementDailyCount() {
        let today = todayString
        if Self.sharedDefaults.string(forKey: Self.dailyDateKey) != today {
            Self.sharedDefaults.set(today, forKey: Self.dailyDateKey)
            Self.sharedDefaults.set(0, forKey: Self.dailyCountKey)
        }
        let newVal = Self.sharedDefaults.integer(forKey: Self.dailyCountKey) + 1
        Self.sharedDefaults.set(newVal, forKey: Self.dailyCountKey)
        todayDecisionCount = newVal
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - iCloud Check
    // Uses the public PHImageResultIsInCloudKey instead of a private KVC key.
    // Requests a tiny image with network disabled; if it isn't available
    // locally, Photos reports it as in iCloud.
    func isInCloud(for id: String) async -> Bool {
        guard let asset = allAssets[id] else { return false }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            var resumed = false
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 64, height: 64),
                                      contentMode: .aspectFill, options: options) { _, info in
                guard !resumed else { return }
                resumed = true
                let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                continuation.resume(returning: inCloud)
            }
        }
    }

    // PHAssetResource exposes a file's byte size only through KVC ("fileSize");
    // there is no public API for an exact size. Centralized here so it's the
    // single place to revisit. nonisolated so background tasks can call it.
    nonisolated static func resourceBytes(_ resource: PHAssetResource) -> Int64 {
        (resource.value(forKey: "fileSize") as? Int64) ?? 0
    }

    // dHash: resize to 9×8, compare each pixel to its right neighbor → 64-bit hash.
    // Much more robust than aHash for distinguishing dark/similar-colored unrelated photos.
    nonisolated static func averageHash(_ image: UIImage) -> UInt64? {
        guard let cgImage = image.cgImage else { return nil }
        let w = 9, h = 8
        var pixels = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        var hash: UInt64 = 0
        for row in 0..<8 {
            for col in 0..<8 {
                if pixels[row * 9 + col] < pixels[row * 9 + col + 1] {
                    hash |= (UInt64(1) << (row * 8 + col))
                }
            }
        }
        return hash
    }

    nonisolated static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    init() {
        authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authStatus = status
        if status == .authorized || status == .limited {
            await loadPhotos()
        }
    }

    func loadPhotos() async {
        isLoading = true
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d || mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        let result = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        var localAssets: [String: PHAsset] = [:]
        var groups: [String: (title: String, ids: [String], videoCount: Int)] = [:]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "MMMM yyyy"
        let keyFormatter = DateFormatter()
        keyFormatter.dateFormat = "yyyy-MM"

        for asset in assets {
            let date = asset.creationDate ?? Date.distantPast
            let key = keyFormatter.string(from: date)
            let title = formatter.string(from: date).capitalized
            localAssets[asset.localIdentifier] = asset
            if groups[key] == nil {
                groups[key] = (title: title, ids: [], videoCount: 0)
            }
            groups[key]!.ids.append(asset.localIdentifier)
            if asset.mediaType == .video { groups[key]!.videoCount += 1 }
        }

        allAssets = localAssets
        favoriteIDs = Set(assets.filter { $0.isFavorite }.map { $0.localIdentifier })

        let decisions = savedDecisions
        var built: [MonthGroup] = groups.map { key, val in
            var dec: [String: PhotoDecision] = [:]
            for id in val.ids {
                if let raw = decisions[id], let d = PhotoDecision(rawValue: raw) {
                    dec[id] = d
                }
            }
            return MonthGroup(id: key, title: val.title, photoIDs: val.ids, videoCount: val.videoCount, decisions: dec)
        }
        built.sort { $0.id > $1.id }

        monthGroups = built
        toDeleteIDs = built.flatMap { group in
            group.photoIDs.filter { (group.decisions[$0] ?? .undecided) == .delete }
        }
        isLoading = false

        // Sync data for widget
        let allIDs    = built.flatMap { $0.photoIDs }
        let total     = allIDs.count
        let undecided = built.reduce(0) { sum, group in
            sum + group.photoIDs.filter { (group.decisions[$0] ?? .undecided) == .undecided }.count
        }
        let reviewed  = total - undecided
        let deleteIDs = built.flatMap { group in
            group.photoIDs.filter { (group.decisions[$0] ?? .undecided) == .delete }
        }
        let keptIDs = built.flatMap { group in
            group.photoIDs.filter { (group.decisions[$0] ?? .undecided) == .keep }
        }
        Self.sharedDefaults.set(undecided,           forKey: "widgetPendingCount")
        Self.sharedDefaults.set(total,               forKey: "widgetTotalCount")
        Self.sharedDefaults.set(reviewed,            forKey: "widgetReviewedCount")
        Self.sharedDefaults.set(totalDeletedCount,   forKey: "widgetDeletedCount")
        Self.sharedDefaults.set(keptIDs.count,       forKey: "widgetKeptCount")

        // Savings bytes — computed off the main thread. Reading PHAsset resources
        // on the main queue triggers on-demand metadata fetches that can stutter
        // on large delete lists.
        let deleteAssets = deleteIDs.compactMap { allAssets[$0] }
        Task.detached(priority: .utility) {
            let savingsBytes = deleteAssets.reduce(Int64(0)) { sum, asset in
                sum + PHAssetResource.assetResources(for: asset).reduce(0) { $0 + Self.resourceBytes($1) }
            }
            Self.sharedDefaults.set(savingsBytes, forKey: "widgetSavingsBytes")
            WidgetCenter.shared.reloadAllTimelines()
        }

        // Year breakdown for large widget
        let yearData = Dictionary(grouping: built) { String($0.id.prefix(4)) }
            .map { year, months -> [String: Any] in
                let t = months.reduce(0) { $0 + $1.photoIDs.count }
                let r = months.reduce(0) { sum, g in
                    sum + g.photoIDs.filter { (g.decisions[$0] ?? .undecided) != .undecided }.count
                }
                return ["year": year, "total": t, "reviewed": r]
            }
            .sorted { ($0["year"] as? String ?? "") > ($1["year"] as? String ?? "") }
        if let encoded = try? JSONSerialization.data(withJSONObject: yearData) {
            Self.sharedDefaults.set(encoded, forKey: "widgetYearData")
        }
        WidgetCenter.shared.reloadAllTimelines()
        loadTodayCount()
        rebuildYearGroups()
    }

    // Stored so @Observable directly tracks it — computed properties don't fire
    // notifications reliably when their dependencies change via nested mutations.
    private(set) var yearGroups: [YearGroup] = []

    private func rebuildYearGroups() {
        let grouped = Dictionary(grouping: monthGroups) { String($0.id.prefix(4)) }
        yearGroups = grouped.map { year, months in
            YearGroup(id: year, title: year, months: months.sorted { $0.id > $1.id })
        }.sorted { $0.id > $1.id }
    }

    func asset(for id: String) -> PHAsset? {
        allAssets[id] ?? PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    func isVideo(for id: String) -> Bool {
        allAssets[id]?.mediaType == .video
    }

    func videoDuration(for id: String) -> TimeInterval? {
        guard let asset = allAssets[id], asset.mediaType == .video else { return nil }
        return asset.duration
    }

    func shareItems(for id: String) async -> [Any] {
        guard let asset = allAssets[id] else { return [] }
        if asset.mediaType == .video {
            return await withCheckedContinuation { continuation in
                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .highQualityFormat
                PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                    if let urlAsset = avAsset as? AVURLAsset {
                        continuation.resume(returning: [urlAsset.url])
                    } else {
                        continuation.resume(returning: [])
                    }
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                var resumed = false
                PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize,
                                                      contentMode: .default, options: options) { image, info in
                    guard !resumed else { return }
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !isDegraded {
                        resumed = true
                        continuation.resume(returning: image.map { [$0] } ?? [])
                    }
                }
            }
        }
    }

    func toggleFavorite(for id: String) async {
        guard let asset = allAssets[id] else { return }
        let newValue = !favoriteIDs.contains(id)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest(for: asset).isFavorite = newValue
            }
            if newValue { favoriteIDs.insert(id) } else { favoriteIDs.remove(id) }
        } catch {}
    }

    func isLivePhoto(for id: String) -> Bool {
        allAssets[id]?.mediaSubtypes.contains(.photoLive) ?? false
    }

    func loadLivePhoto(for id: String, targetSize: CGSize, onProgress: ((Double) -> Void)? = nil) async -> PHLivePhoto? {
        guard let asset = allAssets[id] else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHLivePhotoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.progressHandler = { progress, _, _, _ in
                DispatchQueue.main.async { onProgress?(progress) }
            }
            var resumed = false

            let requestID = imageManager.requestLivePhoto(
                for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options
            ) { livePhoto, info in
                guard !resumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                resumed = true
                continuation.resume(returning: livePhoto)
            }

            // 15s timeout — if iCloud live photo download stalls, fall back to nil (shows as still)
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard !resumed else { return }
                resumed = true
                self?.imageManager.cancelImageRequest(requestID)
                continuation.resume(returning: nil)
            }
        }
    }

    func applyDecision(_ decision: PhotoDecision, to photoID: String, in groupID: String) {
        guard let idx = monthGroups.firstIndex(where: { $0.id == groupID }) else { return }
        var groups = monthGroups
        groups[idx].decisions[photoID] = decision
        monthGroups = groups

        var saved = savedDecisions
        saved[photoID] = decision.rawValue
        savedDecisions = saved

        if decision == .delete {
            if !toDeleteIDs.contains(photoID) { toDeleteIDs.append(photoID) }
        } else {
            toDeleteIDs.removeAll { $0 == photoID }
        }
        rebuildYearGroups()
        incrementDailyCount()
    }

    func undoDecision(for photoID: String, in groupID: String) {
        guard let idx = monthGroups.firstIndex(where: { $0.id == groupID }) else { return }
        var groups = monthGroups
        groups[idx].decisions[photoID] = .undecided
        monthGroups = groups

        var saved = savedDecisions
        saved.removeValue(forKey: photoID)
        savedDecisions = saved

        toDeleteIDs.removeAll { $0 == photoID }
        rebuildYearGroups()
    }

    func resetGroupDecisions(groupID: String) {
        guard let idx = monthGroups.firstIndex(where: { $0.id == groupID }) else { return }
        let photoIDs = monthGroups[idx].photoIDs
        toDeleteIDs.removeAll { photoIDs.contains($0) }
        var groups = monthGroups
        groups[idx].decisions = [:]
        monthGroups = groups
        var saved = savedDecisions
        for id in photoIDs { saved.removeValue(forKey: id) }
        savedDecisions = saved
        rebuildYearGroups()
    }

    // Applies a decision without knowing the group — searches all groups
    func applyDecisionGlobal(_ decision: PhotoDecision, to photoID: String) {
        guard let idx = monthGroups.firstIndex(where: { $0.photoIDs.contains(photoID) }) else { return }
        applyDecision(decision, to: photoID, in: monthGroups[idx].id)
    }

    func undoDecisionGlobal(for photoID: String) {
        guard let idx = monthGroups.firstIndex(where: { $0.photoIDs.contains(photoID) }) else { return }
        undoDecision(for: photoID, in: monthGroups[idx].id)
    }

    // All undecided photo IDs across every month, shuffled
    var allPendingIDs: [String] {
        monthGroups.flatMap { $0.pendingIDs }.shuffled()
    }

    // Bytes of photos marked for delete in a specific group — runs off main thread
    func toDeleteBytes(in groupID: String) async -> Int64 {
        guard let group = monthGroups.first(where: { $0.id == groupID }) else { return 0 }
        let ids = group.decisions.compactMap { id, d in d == .delete ? id : nil }
        let assets = ids.compactMap { allAssets[$0] }
        return await Task.detached(priority: .utility) {
            assets.reduce(0) { sum, asset in
                sum + PHAssetResource.assetResources(for: asset).reduce(0) {
                    $0 + Self.resourceBytes($1)
                }
            }
        }.value
    }

    // Total bytes of all photos in a group — loaded async so it doesn't block
    func totalBytes(in groupID: String) async -> Int64 {
        guard let group = monthGroups.first(where: { $0.id == groupID }) else { return 0 }
        let assets = group.photoIDs.compactMap { allAssets[$0] }
        return await Task.detached(priority: .utility) {
            assets.reduce(0) { sum, asset in
                sum + PHAssetResource.assetResources(for: asset).reduce(0) {
                    $0 + Self.resourceBytes($1)
                }
            }
        }.value
    }

    func removeFromTrash(photoID: String) {
        toDeleteIDs.removeAll { $0 == photoID }
        var groups = monthGroups
        for idx in groups.indices {
            if groups[idx].decisions[photoID] == .delete {
                groups[idx].decisions[photoID] = .undecided
                monthGroups = groups
                var saved = savedDecisions
                saved.removeValue(forKey: photoID)
                savedDecisions = saved
                rebuildYearGroups()
                break
            }
        }
    }

    func removeAllFromTrash() {
        let ids = toDeleteIDs
        for id in ids { removeFromTrash(photoID: id) }
    }

    func permanentlyDeleteTrash() async throws {
        let ids = toDeleteIDs
        let assets = ids.compactMap { allAssets[$0] }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
        var saved = savedDecisions
        for id in ids { saved.removeValue(forKey: id) }
        savedDecisions = saved
        let yearFmt = DateFormatter()
        yearFmt.dateFormat = "yyyy"
        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "yyyy-MM"
        var byYear = deletedCountByYear
        var byMonth = deletedCountByMonth
        for id in ids {
            if let asset = allAssets[id] {
                let date = asset.creationDate ?? Date()
                byYear[yearFmt.string(from: date), default: 0] += 1
                byMonth[monthFmt.string(from: date), default: 0] += 1
            }
        }
        deletedCountByYear = byYear
        deletedCountByMonth = byMonth

        var byAlbum = deletedCountByAlbum
        var albumMap = photoAlbumMap
        for id in ids {
            if let albumID = albumMap[id] {
                byAlbum[albumID, default: 0] += 1
                albumMap.removeValue(forKey: id)
            }
        }
        deletedCountByAlbum = byAlbum
        photoAlbumMap = albumMap

        totalDeletedCount += ids.count
        Self.sharedDefaults.set(totalDeletedCount, forKey: "widgetDeletedCount")
        WidgetCenter.shared.reloadAllTimelines()
        toDeleteIDs = []
        var groups = monthGroups
        for idx in groups.indices {
            for id in ids {
                groups[idx].decisions.removeValue(forKey: id)
                groups[idx].photoIDs.removeAll { $0 == id }
            }
        }
        monthGroups = groups
        rebuildYearGroups()
    }

    // Returns a fast low-res thumbnail — almost instant, used to prevent blank card
    func loadThumbnail(for id: String) async -> UIImage? {
        guard let asset = allAssets[id] else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            var resumed = false
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 400),
                                      contentMode: .aspectFill, options: options) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded && image != nil {
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: image)
                    return
                }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }

    // Returns the full-quality image, skipping degraded intermediate delivery.
    // Falls back to the degraded version after 10s so slow iCloud downloads never hang.
    func loadImage(for id: String, targetSize: CGSize, onProgress: ((Double) -> Void)? = nil, onNeedsCloudFetch: (() -> Void)? = nil) async -> UIImage? {
        let asset = allAssets[id] ?? PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
        guard let asset else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isSynchronous = false
            options.progressHandler = { progress, _, _, _ in
                DispatchQueue.main.async { onProgress?(progress) }
            }
            var resumed = false
            var degradedFallback: UIImage? = nil

            let requestID = imageManager.requestImage(
                for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded {
                    if !resumed {
                        degradedFallback = image
                        // Photos tells us right here (no need to wait for the
                        // timeout) that the full-quality version lives in
                        // iCloud and hasn't been fetched yet.
                        let needsCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                        if needsCloud {
                            DispatchQueue.main.async { onNeedsCloudFetch?() }
                        }
                    }
                    return
                }
                guard !resumed else { return }
                resumed = true
                // A non-degraded ("final") delivery can still be a failure — when
                // the iCloud fetch errors out (e.g. no connection), Photos calls
                // back with isDegraded == false and whatever local data it has,
                // but stashes the real failure in PHImageErrorKey.
                let requestError = info?[PHImageErrorKey] as? Error
                if requestError != nil {
                    DispatchQueue.main.async { onNeedsCloudFetch?() }
                }
                continuation.resume(returning: image ?? degradedFallback)
            }

            // 10s without a full-quality delivery means the full asset never
            // arrived from iCloud — even if `isInCloud` reported false (that
            // check only inspects a tiny local thumbnail, so it can be wrong).
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard !resumed else { return }
                resumed = true
                self?.imageManager.cancelImageRequest(requestID)
                onNeedsCloudFetch?()
                continuation.resume(returning: degradedFallback)
            }
        }
    }

    func loadLibraryStats() async {
        guard !statsLoading && !statsLoaded else { return }
        statsLoading = true
        await Task.yield() // flush any pending UI state before starting

        let photoFetch = PHAsset.fetchAssets(with: .image, options: nil)
        let videoFetch = PHAsset.fetchAssets(with: .video, options: nil)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            photoCount = photoFetch.count
            videoCount = videoFetch.count
        }

        // Fire-and-forget — caller returns immediately, results stream via MainActor
        Task.detached(priority: .userInitiated) {
            let hashMgr = PHImageManager()
            let hOpts = PHImageRequestOptions()
            hOpts.deliveryMode = .fastFormat
            hOpts.resizeMode   = .fast
            hOpts.isSynchronous = true
            hOpts.isNetworkAccessAllowed = false
            let monthFmt = DateFormatter(); monthFmt.dateFormat = "yyyy-MM"

            // Helper: hash + compare a batch of assets, stream any groups found
            func scanBatch(_ assets: [PHAsset], seen: inout Set<String>, seenKeys: inout Set<String>) {
                var byMonth: [String: [PHAsset]] = [:]
                for asset in assets {
                    let m = monthFmt.string(from: asset.creationDate ?? Date.distantPast)
                    byMonth[m, default: []].append(asset)
                }
                for month in byMonth.keys.sorted().reversed() {
                    var hashes: [(id: String, hash: UInt64)] = []
                    for asset in byMonth[month] ?? [] {
                        guard !seen.contains(asset.localIdentifier) else { continue }
                        var img: UIImage?
                        hashMgr.requestImage(for: asset,
                                             targetSize: CGSize(width: 9, height: 8),
                                             contentMode: .aspectFill,
                                             options: hOpts) { i, _ in img = i }
                        if let img, let h = Self.averageHash(img) {
                            hashes.append((id: asset.localIdentifier, hash: h))
                        }
                    }
                    var buckets: [[String]] = []
                    for i in 0..<hashes.count {
                        guard !seen.contains(hashes[i].id) else { continue }
                        var group = [hashes[i].id]
                        for j in (i + 1)..<hashes.count {
                            guard !seen.contains(hashes[j].id) else { continue }
                            if Self.hammingDistance(hashes[i].hash, hashes[j].hash) <= 6 {
                                group.append(hashes[j].id)
                            }
                        }
                        if group.count >= 2 {
                            group.forEach { seen.insert($0) }
                            buckets.append(group)
                        }
                    }
                    if !buckets.isEmpty {
                        let toAdd = buckets
                        Task { @MainActor in
                            let existing = Set(self.duplicateGroups.map { $0.sorted().joined(separator: ",") })
                            for ids in toAdd where !existing.contains(ids.sorted().joined(separator: ",")) {
                                self.duplicateGroups.append(ids)
                            }
                        }
                        for ids in buckets { seenKeys.insert(ids.sorted().joined(separator: ",")) }
                    }
                }
            }

            // FAST PATH: hash the most recent 500 photos immediately (no enumeration wait)
            let quickCount = min(500, photoFetch.count)
            var quickAssets: [PHAsset] = []
            for i in 0..<quickCount { quickAssets.append(photoFetch.object(at: i)) }
            var visualSeen = Set<String>()
            var seenKeys   = Set<String>()
            scanBatch(quickAssets, seen: &visualSeen, seenKeys: &seenKeys)

            // FULL ENUMERATION: metadata stats + remaining photos
            var pBytes: Int64 = 0
            var vBytes: Int64 = 0
            var yearMap: [String: Int64] = [:]
            let yearFormatter = DateFormatter(); yearFormatter.dateFormat = "yyyy"
            var sizeDimBuckets: [String: [String]] = [:]
            var burstBuckets:   [String: [String]] = [:]
            var allPhotoAssets: [PHAsset] = []
            var top5Photos: [(id: String, bytes: Int64, date: Date)] = []
            var counter = 0

            photoFetch.enumerateObjects { asset, _, _ in
                var size: Int64 = 0
                for resource in PHAssetResource.assetResources(for: asset) {
                    size += Self.resourceBytes(resource)
                }
                pBytes += size
                let date = asset.creationDate ?? Date.distantPast
                yearMap[yearFormatter.string(from: date), default: 0] += size
                let dim = "\(asset.pixelWidth)x\(asset.pixelHeight)"
                let id  = asset.localIdentifier
                if size > 10_000 { sizeDimBuckets["\(size)_\(dim)", default: []].append(id) }
                if let burst = asset.burstIdentifier { burstBuckets[burst, default: []].append(id) }
                allPhotoAssets.append(asset)
                top5Photos.append((id: id, bytes: size, date: date))
                if top5Photos.count > 5 {
                    top5Photos.sort { $0.bytes > $1.bytes }
                    top5Photos = Array(top5Photos.prefix(5))
                }
                counter += 1
                if counter % 200 == 0 {
                    let snapshot = top5Photos; let pb = pBytes
                    Task { @MainActor in self.largestPhotos = snapshot; self.photoBytes = pb }
                }
            }

            // Emit burst + exact-size-dim matches from metadata
            var fastGroups: [[String]] = []
            for (_, ids) in sizeDimBuckets where ids.count >= 2 {
                let key = ids.sorted().joined(separator: ",")
                if seenKeys.insert(key).inserted { fastGroups.append(ids) }
            }
            for (_, ids) in burstBuckets where ids.count >= 2 {
                let key = ids.sorted().joined(separator: ",")
                if seenKeys.insert(key).inserted { fastGroups.append(ids) }
            }
            // Trickle these in a chunk at a time instead of one big dump — the
            // full-enumeration loop above runs silently with no UI feedback,
            // so dropping hundreds of groups on the screen at once right after
            // it finishes reads as "nothing, then everything at once."
            if !fastGroups.isEmpty {
                let chunkSize = 12
                var idx = 0
                while idx < fastGroups.count {
                    let chunk = Array(fastGroups[idx..<min(idx + chunkSize, fastGroups.count)])
                    await MainActor.run {
                        let existing = Set(self.duplicateGroups.map { $0.sorted().joined(separator: ",") })
                        for ids in chunk where !existing.contains(ids.sorted().joined(separator: ",")) {
                            self.duplicateGroups.append(ids)
                        }
                    }
                    idx += chunkSize
                    if idx < fastGroups.count {
                        try? await Task.sleep(nanoseconds: 80_000_000)
                    }
                }
            }

            // Hash remaining photos (501 onward) month-by-month
            let remaining = Array(allPhotoAssets.dropFirst(quickCount).prefix(2500))
            scanBatch(remaining, seen: &visualSeen, seenKeys: &seenKeys)

            // Video enumeration
            var top5Videos: [(id: String, bytes: Int64, date: Date, duration: TimeInterval)] = []
            var vCounter = 0
            videoFetch.enumerateObjects { asset, _, _ in
                var size: Int64 = 0
                for resource in PHAssetResource.assetResources(for: asset) {
                    size += Self.resourceBytes(resource)
                }
                vBytes += size
                let date = asset.creationDate ?? Date.distantPast
                yearMap[yearFormatter.string(from: date), default: 0] += size
                top5Videos.append((id: asset.localIdentifier, bytes: size, date: date, duration: asset.duration))
                if top5Videos.count > 5 {
                    top5Videos.sort { $0.bytes > $1.bytes }
                    top5Videos = Array(top5Videos.prefix(5))
                }
                vCounter += 1
                if vCounter % 100 == 0 {
                    let snapshot = top5Videos; let vb = vBytes
                    Task { @MainActor in self.largestVideos = snapshot; self.videoBytes = vb }
                }
            }

            let yearly = yearMap.map { (year: $0.key, bytes: $0.value) }.sorted { $0.year > $1.year }
            let finalPhotos = top5Photos.sorted { $0.bytes > $1.bytes }
            let finalVideos = top5Videos.sorted { $0.bytes > $1.bytes }
            let finalVB = vBytes
            Task { @MainActor in
                self.photoBytes    = pBytes
                self.videoBytes    = finalVB
                self.yearlyStorage = yearly
                self.largestPhotos = finalPhotos
                self.largestVideos = finalVideos
                self.statsLoading  = false
                self.statsLoaded   = true
            }
        }
        // Returns immediately — scan streams results in background
    }

    func startCaching(ids: [String], targetSize: CGSize) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids.filter { allAssets[$0] == nil }, options: nil)
        var extra: [PHAsset] = []
        fetchResult.enumerateObjects { a, _, _ in extra.append(a) }
        let assets = ids.compactMap { allAssets[$0] } + extra
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: options)
    }
}
