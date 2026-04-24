import Foundation

enum L10nFormat {
    static func decimal(_ value: Double, digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", value)
    }

    static func signedDecimal(_ value: Double, digits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%+.\(digits)f", value)
    }

    static func coordinate(_ value: Double) -> String {
        "\(decimal(value, digits: 4))°"
    }

    static func seconds(_ value: Double) -> String {
        "\(decimal(value, digits: 1))s"
    }

    static func exposure(_ seconds: Double) -> String {
        guard seconds < 0.1, seconds > 0 else {
            return self.seconds(seconds)
        }

        let denominator = max(1, Int((1 / seconds).rounded()))
        return "1/\(denominator)"
    }

    static func duration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = [.dropLeading]
        formatter.calendar?.locale = .autoupdatingCurrent
        return formatter.string(from: max(0, seconds)) ?? "\(Int(seconds.rounded()))s"
    }

    static func sqm(_ value: Double) -> String {
        "\(decimal(value, digits: 2)) mag/arcsec\u{00B2}"
    }

    static func brightness(_ value: Double) -> String {
        "\(decimal(value, digits: 2)) mcd/m\u{00B2}"
    }

    static func ratio(_ current: Int, _ total: Int) -> String {
        "\(current)/\(total)"
    }

    static func projectDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMddjm")
        return formatter.string(from: date)
    }

    static func projectTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }
}
