import Foundation

struct ProgressValue: Equatable {
    let completed: Int
    let total: Int

    var fractionCompleted: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}
