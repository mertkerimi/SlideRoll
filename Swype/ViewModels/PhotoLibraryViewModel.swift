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
    var statsLoading = false

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

            photoFetch.enumerateObjects { asset, _, _ in
                for resource in PHAssetResource.assetResources(for: asset) {
                    pBytes += (resource.value(forKey: "fileSize") as? Int64) ?? 0
                }
            }
            videoFetch.enumerateObjects { asset, _, _ in
                for resource in PHAssetResource.assetResources(for: asset) {
                    vBytes += (resource.value(forKey: "fileSize") as? Int64) ?? 0
                }
            }

            return (photoFetch.count, videoFetch.count, pBytes, vBytes)
        }.value

        photoCount = result.0
        videoCount = result.1
        photoBytes = result.2
        videoBytes = result.3
        statsLoading = false
    }

    func startCaching(ids: [String], targetSize: CGSize) {
        let assets = ids.compactMap { allAssets[$0] }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: options)
    }
}
