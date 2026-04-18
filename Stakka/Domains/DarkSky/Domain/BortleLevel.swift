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
        switch self {
        case .one: return "优秀暗空"
        case .two: return "极佳暗空"
        case .three: return "乡村暗空"
        case .four: return "城郊过渡"
        case .five: return "城郊天空"
        case .six: return "明亮城郊"
        case .seven: return "近城区"
        case .eight: return "城市天空"
        case .nine: return "市中心"
        }
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
