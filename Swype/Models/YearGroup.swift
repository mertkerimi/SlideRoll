import Foundation

struct YearGroup: Identifiable, Hashable {
    static func == (lhs: YearGroup, rhs: YearGroup) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String  // "2026"
    let title: String
    var months: [MonthGroup]

    var total: Int      { months.reduce(0) { $0 + $1.total } }
    var reviewed: Int   { months.reduce(0) { $0 + $1.reviewed } }
    var videoCount: Int { months.reduce(0) { $0 + $1.videoCount } }
    var photoCount: Int { total - videoCount }
    var progress: Double { total > 0 ? Double(reviewed) / Double(total) : 0 }
    var isCompleted: Bool { months.allSatisfy(\.isCompleted) }
}
