import Foundation
import Photos

enum PhotoDecision: String, Codable {
    case keep
    case delete
    case skip
    case undecided
}

struct PhotoItem: Identifiable {
    let id: String // PHAsset localIdentifier
    let asset: PHAsset
    var decision: PhotoDecision = .undecided

    var creationDate: Date {
        asset.creationDate ?? Date.distantPast
    }
}
