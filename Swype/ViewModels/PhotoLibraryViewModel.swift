import Foundation
import Photos
import SwiftUI
import Observation
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
    var favoritesCount: Int = 0
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
    var statsLoading = false
    private var statsLoaded = false

    // Trash size — computed on demand
    var trashBytes: Int64 {
        toDeleteIDs.compactMap { allAssets[$0] }.reduce(0) { sum, asset in
            sum + PHAssetResource.assetResources(for: asset).reduce(0) {
                $0 + Self.resourceBytes($1)
            }
        }
    }

    // Cumulative stats — persisted across sessions
    var totalDeletedCount: Int {
        get { UserDefaults.standard.integer(forKey: "TotalDeletedCount") }
        set { UserDefaults.standard.set(newValue, forKey: "TotalDeletedCount") }
    }

    var deletedCountByYear: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: "DeletedCountByYear") as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "DeletedCountByYear") }
    }

    var deletedCountByMonth: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: "DeletedCountByMonth") as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "DeletedCountByMonth") }
    }

    let imageManager = PHCachingImageManager()
    private let persistenceKey = "PhotoCleanerDecisions"
    private var allAssets: [String: PHAsset] = [:]

    private var savedDecisions: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: persistenceKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: persistenceKey) }
    }

    // MARK: - Daily Stats
    private static let sharedDefaults = UserDefaults(suiteName: "group.com.mertkerimi.Swype") ?? .standard
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
        let savingsBytes = deleteIDs.compactMap { allAssets[$0] }.reduce(Int64(0)) { sum, asset in
            sum + PHAssetResource.assetResources(for: asset).reduce(0) { $0 + Self.resourceBytes($1) }
        }
        Self.sharedDefaults.set(undecided,           forKey: "widgetPendingCount")
        Self.sharedDefaults.set(total,               forKey: "widgetTotalCount")
        Self.sharedDefaults.set(reviewed,            forKey: "widgetReviewedCount")
        Self.sharedDefaults.set(savingsBytes,        forKey: "widgetSavingsBytes")
        Self.sharedDefaults.set(totalDeletedCount,   forKey: "widgetDeletedCount")
        Self.sharedDefaults.set(keptIDs.count,       forKey: "widgetKeptCount")

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

    func asset(for id: String) -> PHAsset? { allAssets[id] }

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

    func loadLivePhoto(for id: String, targetSize: CGSize) async -> PHLivePhoto? {
        guard let asset = allAssets[id] else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHLivePhotoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
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
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            var resumed = false
            imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 400),
                                      contentMode: .aspectFill, options: options) { image, _ in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }

    // Returns the full-quality image, skipping degraded intermediate delivery.
    // Falls back to the degraded version after 10s so slow iCloud downloads never hang.
    func loadImage(for id: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = allAssets[id] else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isSynchronous = false
            var resumed = false
            var degradedFallback: UIImage? = nil

            let requestID = imageManager.requestImage(
                for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded {
                    if !resumed { degradedFallback = image }
                    return
                }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard !resumed else { return }
                resumed = true
                self?.imageManager.cancelImageRequest(requestID)
                continuation.resume(returning: degradedFallback)
            }
        }
    }

    func loadLibraryStats() async {
        guard !statsLoading && !statsLoaded else { return }
        statsLoading = true

        // Phase 1: instant counts — PHFetchResult.count requires no enumeration
        let photoFetch = PHAsset.fetchAssets(with: .image, options: nil)
        let videoFetch = PHAsset.fetchAssets(with: .video, options: nil)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            photoCount = photoFetch.count
            videoCount = videoFetch.count
        }

        // Phase 2: streaming enumeration — update top-5 + totals every 200 assets
        await Task.detached(priority: .userInitiated) {
            var pBytes: Int64 = 0
            var vBytes: Int64 = 0
            var favorites = 0
            var yearMap: [String: Int64] = [:]
            let dayFormatter = DateFormatter(); dayFormatter.dateFormat = "yyyy-MM-dd"
            let yearFormatter = DateFormatter(); yearFormatter.dateFormat = "yyyy"
            var dayBuckets: [String: [(id: String, size: Int64)]] = [:]
            var top5Photos: [(id: String, bytes: Int64, date: Date)] = []
            var counter = 0

            photoFetch.enumerateObjects { asset, _, _ in
                var size: Int64 = 0
                for resource in PHAssetResource.assetResources(for: asset) {
                    size += Self.resourceBytes(resource)
                }
                pBytes += size
                if asset.isFavorite { favorites += 1 }
                let date = asset.creationDate ?? Date.distantPast
                yearMap[yearFormatter.string(from: date), default: 0] += size
                dayBuckets[dayFormatter.string(from: date), default: []].append((id: asset.localIdentifier, size: size))

                // Keep running top-5
                top5Photos.append((id: asset.localIdentifier, bytes: size, date: date))
                if top5Photos.count > 5 {
                    top5Photos.sort { $0.bytes > $1.bytes }
                    top5Photos = Array(top5Photos.prefix(5))
                }

                counter += 1
                if counter % 200 == 0 {
                    let snapshot = top5Photos
                    let pb = pBytes
                    Task { @MainActor in self.largestPhotos = snapshot; self.photoBytes = pb }
                }
            }

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
                    let snapshot = top5Videos
                    let vb = vBytes
                    Task { @MainActor in self.largestVideos = snapshot; self.videoBytes = vb }
                }
            }

            // Final results
            var dupGroups: [[String]] = []
            for (_, items) in dayBuckets {
                var sizeMap: [Int64: [String]] = [:]
                for item in items { sizeMap[item.size, default: []].append(item.id) }
                for (_, ids) in sizeMap where ids.count >= 2 { dupGroups.append(ids) }
            }
            let yearly = yearMap.map { (year: $0.key, bytes: $0.value) }.sorted { $0.year > $1.year }
            let finalPhotos = top5Photos.sorted { $0.bytes > $1.bytes }
            let finalVideos = top5Videos.sorted { $0.bytes > $1.bytes }

            Task { @MainActor in
                self.photoBytes      = pBytes
                self.videoBytes      = vBytes
                self.favoritesCount  = favorites
                self.duplicateGroups = dupGroups
                self.yearlyStorage   = yearly
                self.largestPhotos   = finalPhotos
                self.largestVideos   = finalVideos
                self.statsLoading    = false
                self.statsLoaded     = true
            }
        }.value
    }

    func startCaching(ids: [String], targetSize: CGSize) {
        let assets = ids.compactMap { allAssets[$0] }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: options)
    }
}
