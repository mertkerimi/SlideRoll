import Foundation
import Photos
import SwiftUI
import Observation

@Observable
@MainActor
class PhotoLibraryViewModel {
    var authStatus: PHAuthorizationStatus = .notDetermined
    var monthGroups: [MonthGroup] = []
    var isLoading = false
    var toDeleteIDs: [String] = []

    // Library stats
    var photoCount: Int = 0
    var videoCount: Int = 0
    var photoBytes: Int64 = 0
    var videoBytes: Int64 = 0
    var favoritesCount: Int = 0
    var duplicateGroups: [[String]] = []
    var yearlyStorage: [(year: String, bytes: Int64)] = []

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

    // Trash size — computed on demand
    var trashBytes: Int64 {
        toDeleteIDs.compactMap { allAssets[$0] }.reduce(0) { sum, asset in
            sum + PHAssetResource.assetResources(for: asset).reduce(0) {
                $0 + ((($1.value(forKey: "fileSize") as? Int64) ?? 0))
            }
        }
    }

    // Cumulative stats — persisted across sessions
    var totalDeletedCount: Int {
        get { UserDefaults.standard.integer(forKey: "TotalDeletedCount") }
        set { UserDefaults.standard.set(newValue, forKey: "TotalDeletedCount") }
    }

    let imageManager = PHCachingImageManager()
    private let persistenceKey = "PhotoCleanerDecisions"
    private var allAssets: [String: PHAsset] = [:]

    private var savedDecisions: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: persistenceKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: persistenceKey) }
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
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        var localAssets: [String: PHAsset] = [:]
        var groups: [String: (title: String, ids: [String])] = [:]
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
                groups[key] = (title: title, ids: [])
            }
            groups[key]!.ids.append(asset.localIdentifier)
        }

        allAssets = localAssets

        let decisions = savedDecisions
        var built: [MonthGroup] = groups.map { key, val in
            var dec: [String: PhotoDecision] = [:]
            for id in val.ids {
                if let raw = decisions[id], let d = PhotoDecision(rawValue: raw) {
                    dec[id] = d
                }
            }
            return MonthGroup(id: key, title: val.title, photoIDs: val.ids, decisions: dec)
        }
        built.sort { $0.id > $1.id }

        monthGroups = built
        toDeleteIDs = built.flatMap { group in
            group.photoIDs.filter { (group.decisions[$0] ?? .undecided) == .delete }
        }
        isLoading = false
    }

    var yearGroups: [YearGroup] {
        let grouped = Dictionary(grouping: monthGroups) { String($0.id.prefix(4)) }
        return grouped.map { year, months in
            YearGroup(id: year, title: year, months: months.sorted { $0.id > $1.id })
        }.sorted { $0.id > $1.id }
    }

    func asset(for id: String) -> PHAsset? { allAssets[id] }

    func applyDecision(_ decision: PhotoDecision, to photoID: String, in groupID: String) {
        guard let idx = monthGroups.firstIndex(where: { $0.id == groupID }) else { return }
        monthGroups[idx].decisions[photoID] = decision

        var saved = savedDecisions
        saved[photoID] = decision.rawValue
        savedDecisions = saved

        if decision == .delete {
            if !toDeleteIDs.contains(photoID) { toDeleteIDs.append(photoID) }
        } else {
            toDeleteIDs.removeAll { $0 == photoID }
        }
    }

    func undoDecision(for photoID: String, in groupID: String) {
        guard let idx = monthGroups.firstIndex(where: { $0.id == groupID }) else { return }
        monthGroups[idx].decisions[photoID] = .undecided

        var saved = savedDecisions
        saved.removeValue(forKey: photoID)
        savedDecisions = saved

        toDeleteIDs.removeAll { $0 == photoID }
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

    // Bytes of photos marked for delete in a specific group (fast — only iterates decided IDs)
    func toDeleteBytes(in groupID: String) -> Int64 {
        guard let group = monthGroups.first(where: { $0.id == groupID }) else { return 0 }
        let ids = group.decisions.compactMap { id, d in d == .delete ? id : nil }
        return ids.compactMap { allAssets[$0] }.reduce(0) { sum, asset in
            sum + PHAssetResource.assetResources(for: asset).reduce(0) {
                $0 + (($1.value(forKey: "fileSize") as? Int64) ?? 0)
            }
        }
    }

    // Total bytes of all photos in a group — loaded async so it doesn't block
    func totalBytes(in groupID: String) async -> Int64 {
        guard let group = monthGroups.first(where: { $0.id == groupID }) else { return 0 }
        let assets = group.photoIDs.compactMap { allAssets[$0] }
        return await Task.detached(priority: .utility) {
            assets.reduce(0) { sum, asset in
                sum + PHAssetResource.assetResources(for: asset).reduce(0) {
                    $0 + (($1.value(forKey: "fileSize") as? Int64) ?? 0)
                }
            }
        }.value
    }

    func removeFromTrash(photoID: String) {
        toDeleteIDs.removeAll { $0 == photoID }
        for idx in monthGroups.indices {
            if monthGroups[idx].decisions[photoID] == .delete {
                monthGroups[idx].decisions[photoID] = .undecided
                var saved = savedDecisions
                saved.removeValue(forKey: photoID)
                savedDecisions = saved
                break
            }
        }
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
        totalDeletedCount += ids.count
        toDeleteIDs = []
        for idx in monthGroups.indices {
            for id in ids {
                monthGroups[idx].decisions.removeValue(forKey: id)
                monthGroups[idx].photoIDs.removeAll { $0 == id }
            }
        }
    }

    func loadImage(for id: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = allAssets[id] else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            var resumed = false
            imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
                guard !resumed else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    resumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func loadLibraryStats() async {
        guard !statsLoading else { return }
        statsLoading = true

        let result = await Task.detached(priority: .userInitiated) {
            let photoFetch = PHAsset.fetchAssets(with: .image, options: nil)
            let videoFetch = PHAsset.fetchAssets(with: .video, options: nil)

            var pBytes: Int64 = 0
            var vBytes: Int64 = 0
            var favorites = 0
            // year -> bytes (photos + videos)
            var yearMap: [String: Int64] = [:]
            // duplicate detection: day+size -> [assetID]
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            var dayBuckets: [String: [(id: String, size: Int64)]] = [:]
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"

            photoFetch.enumerateObjects { asset, _, _ in
                var size: Int64 = 0
                for resource in PHAssetResource.assetResources(for: asset) {
                    size += (resource.value(forKey: "fileSize") as? Int64) ?? 0
                }
                pBytes += size
                if asset.isFavorite { favorites += 1 }

                let date = asset.creationDate ?? Date.distantPast
                let year = yearFormatter.string(from: date)
                yearMap[year, default: 0] += size

                let day = dayFormatter.string(from: date)
                dayBuckets[day, default: []].append((id: asset.localIdentifier, size: size))
            }

            videoFetch.enumerateObjects { asset, _, _ in
                var size: Int64 = 0
                for resource in PHAssetResource.assetResources(for: asset) {
                    size += (resource.value(forKey: "fileSize") as? Int64) ?? 0
                }
                vBytes += size
                let date = asset.creationDate ?? Date.distantPast
                let year = yearFormatter.string(from: date)
                yearMap[year, default: 0] += size
            }

            // Find duplicates: same day, same file size → group them
            var dupGroups: [[String]] = []
            for (_, items) in dayBuckets {
                // group by size
                var sizeMap: [Int64: [String]] = [:]
                for item in items { sizeMap[item.size, default: []].append(item.id) }
                for (_, ids) in sizeMap where ids.count >= 2 {
                    dupGroups.append(ids)
                }
            }

            let yearly = yearMap
                .map { (year: $0.key, bytes: $0.value) }
                .sorted { $0.year > $1.year }

            return (photoFetch.count, videoFetch.count, pBytes, vBytes, favorites, dupGroups, yearly)
        }.value

        photoCount      = result.0
        videoCount      = result.1
        photoBytes      = result.2
        videoBytes      = result.3
        favoritesCount  = result.4
        duplicateGroups = result.5
        yearlyStorage   = result.6
        statsLoading    = false
    }

    func startCaching(ids: [String], targetSize: CGSize) {
        let assets = ids.compactMap { allAssets[$0] }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: options)
    }
}
