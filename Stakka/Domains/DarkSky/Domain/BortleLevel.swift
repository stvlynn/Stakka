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
        case .one: return .bortleMapOne
        case .two: return .bortleMapTwo
        case .three: return .bortleMapThree
        case .four: return .bortleMapFour
        case .five: return .bortleMapFive
        case .six: return .bortleMapSix
        case .seven: return .bortleMapSeven
        case .eight: return .bortleMapEight
        case .nine: return .bortleMapNine
        }
    }

    var sqmValue: Double {
        switch self {
        case .one: return 22.00
        case .two: return 21.93
        case .three: return 21.79
        case .four: return 21.09
        case .five: return 20.00
        case .six: return 19.22
        case .seven: return 18.66
        case .eight: return 18.19
        case .nine: return 17.50
        }
    }

    var artificialBrightness: Double {
        switch self {
        case .one: return 0.01
        case .two: return 0.04
        case .three: return 0.11
        case .four: return 0.33
        case .five: return 1.00
        case .six: return 3.00
        case .seven: return 10.0
        case .eight: return 30.0
        case .nine: return 100.0
        }
    }

    var darkSkyGrade: Int {
        switch self {
        case .one, .two: return 1
        case .three: return 2
        case .four, .five: return 3
        case .six, .seven: return 4
        case .eight, .nine: return 5
        }
    }

    var darkSkyGradeTitle: String {
        L10n.DarkSky.darkSkyGrade(level: darkSkyGrade)
    }

    var milkyWayVisibility: String {
        switch self {
        case .one, .two: return L10n.DarkSky.milkyWaySpectacular
        case .three: return L10n.DarkSky.milkyWayClear
        case .four: return L10n.DarkSky.milkyWayPartial
        case .five, .six: return L10n.DarkSky.milkyWayCoreOnly
        case .seven, .eight, .nine: return L10n.DarkSky.milkyWayInvisible
        }
    }

    var galaxyVisibility: String {
        switch self {
        case .one: return L10n.DarkSky.galaxyBoth
        case .two, .three: return L10n.DarkSky.galaxyM31
        case .four: return L10n.DarkSky.galaxyBarely
        case .five, .six, .seven, .eight, .nine: return L10n.DarkSky.galaxyInvisible
        }
    }

    var zodiacalLightVisibility: String {
        switch self {
        case .one: return L10n.DarkSky.zodiacalVeryClear
        case .two: return L10n.DarkSky.zodiacalClear
        case .three: return L10n.DarkSky.zodiacalVisible
        case .four, .five, .six, .seven, .eight, .nine: return L10n.DarkSky.zodiacalInvisible
        }
    }
}
