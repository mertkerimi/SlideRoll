import Foundation

struct MonthGroup: Identifiable, Equatable {
    static func == (lhs: MonthGroup, rhs: MonthGroup) -> Bool { lhs.id == rhs.id }
    let id: String // "2026-01"
    let title: String  // "Ocak 2026"
    var photoIDs: [String]
    var videoCount: Int
    var decisions: [String: PhotoDecision]

    var total: Int { photoIDs.count }
    var photoCount: Int { photoIDs.count - videoCount }
    var reviewed: Int { decisions.values.filter { $0 == .keep || $0 == .delete }.count }
    var progress: Double { total > 0 ? Double(reviewed) / Double(total) : 0 }
    var isCompleted: Bool { reviewed == total }

    var pendingIDs: [String] {
        photoIDs.filter { id in
            let d = decisions[id] ?? .undecided
            return d == .undecided || d == .skip
        }
    }
}
