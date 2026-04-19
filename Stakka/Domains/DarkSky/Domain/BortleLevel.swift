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

    var mapColor: Color {
        switch self {
        case .one: return Color(red: 0, green: 1, blue: 0)
        case .two: return Color(red: 0.25, green: 1, blue: 0)
        case .three: return Color(red: 0.5, green: 1, blue: 0)
        case .four: return Color(red: 1, green: 1, blue: 0)
        case .five: return Color(red: 1, green: 0.84, blue: 0)
        case .six: return Color(red: 1, green: 0.65, blue: 0)
        case .seven: return Color(red: 1, green: 0.42, blue: 0)
        case .eight: return Color(red: 1, green: 0, blue: 0)
        case .nine: return Color(red: 1, green: 0.08, blue: 0.58)
        }
    }
}
