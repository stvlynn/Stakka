import Foundation
import Combine

extension Set where Element == AnyCancellable {
    mutating func store(_ cancellable: AnyCancellable) {
        cancellable.store(in: &self)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension ISO8601DateFormatter {
    static var fileSafe: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }
}
