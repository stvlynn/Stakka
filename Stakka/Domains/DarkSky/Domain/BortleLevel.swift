import SwiftUI

enum BortleLevel: Int, CaseIterable, Codable, Sendable {
    case one = 1
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight
    case nine

    var title: String {
        L10n.DarkSky.bortleTitle(level: rawValue)
    }

    var color: Color {
        switch self {
        case .one: return .green
        case .two: return .mint
        case .three: return .yellow
        case .four: return .orange
        case .five: return .orange
        case .six: return .red.opacity(0.8)
        case .seven: return .red
        case .eight: return .red.opacity(0.9)
        case .nine: return .pink
        }
    }
}
