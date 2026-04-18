import UIKit

enum TestImageFactory {
    static func starField(
        size: CGSize = CGSize(width: 96, height: 96),
        stars: [CGPoint],
        offset: CGSize = .zero
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.white.setFill()
            for star in stars {
                let point = CGPoint(x: star.x + offset.width, y: star.y + offset.height)
                context.cgContext.fillEllipse(in: CGRect(x: point.x, y: point.y, width: 3, height: 3))
            }
        }
    }

    static func cometField(
        size: CGSize = CGSize(width: 96, height: 96),
        stars: [CGPoint],
        cometCenter: CGPoint
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.white.setFill()
            for star in stars {
                context.cgContext.fillEllipse(in: CGRect(x: star.x, y: star.y, width: 3, height: 3))
            }

            let colors = [
                UIColor.white.cgColor,
                UIColor.white.withAlphaComponent(0.2).cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 0.45, 1]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)!
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: cometCenter,
                startRadius: 0,
                endCenter: cometCenter,
                endRadius: 10,
                options: [.drawsAfterEndLocation]
            )
        }
    }
}
