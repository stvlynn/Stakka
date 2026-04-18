import UIKit
import CoreImage
import Combine

actor ImageStacker {
    private let context = CIContext()

    func stackImages(_ images: [UIImage]) async -> UIImage? {
        guard !images.isEmpty else { return nil }

        let ciImages = images.compactMap { image -> CIImage? in
            guard let cgImage = image.cgImage else { return nil }
            return CIImage(cgImage: cgImage)
        }

        guard !ciImages.isEmpty else { return nil }

        return await meanStack(ciImages)
    }

    private func meanStack(_ images: [CIImage]) async -> UIImage? {
        guard let firstImage = images.first else { return nil }

        let width = Int(firstImage.extent.width)
        let height = Int(firstImage.extent.height)

        var redSum = Array(repeating: Array(repeating: 0.0, count: width), count: height)
        var greenSum = Array(repeating: Array(repeating: 0.0, count: width), count: height)
        var blueSum = Array(repeating: Array(repeating: 0.0, count: width), count: height)

        for ciImage in images {
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { continue }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let bitsPerComponent = 8

            var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

            guard let context = CGContext(
                data: &pixelData,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * bytesPerPixel
                    redSum[y][x] += Double(pixelData[offset])
                    greenSum[y][x] += Double(pixelData[offset + 1])
                    blueSum[y][x] += Double(pixelData[offset + 2])
                }
            }
        }

        let count = Double(images.count)
        var resultPixels = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                resultPixels[offset] = UInt8(redSum[y][x] / count)
                resultPixels[offset + 1] = UInt8(greenSum[y][x] / count)
                resultPixels[offset + 2] = UInt8(blueSum[y][x] / count)
                resultPixels[offset + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let provider = CGDataProvider(data: Data(resultPixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
