import Foundation

struct YearGroup: Identifiable {
    let id: String  // "2026"
    let title: String
    var months: [MonthGroup]

    var total: Int { months.reduce(0) { $0 + $1.total } }
    var reviewed: Int { months.reduce(0) { $0 + $1.reviewed } }
    var progress: Double { total > 0 ? Double(reviewed) / Double(total) : 0 }
    var isCompleted: Bool { months.allSatisfy(\.isCompleted) }
}
