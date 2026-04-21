import UIKit

/// Pixel-level image factory used to port DeepSkyStacker test fixtures
/// (https://github.com/deepskystacker/DSS) into Stakka.
///
/// DSS tests fill `CGrayBitmap` / `CColorBitmap` buffers directly with
/// uniform fields, gradients, Bayer mosaics, or small bright blocks and
/// then run them through the pipeline under test.  Rather than ship
/// hundreds of binary PNG fixtures, this factory reproduces the exact
/// same synthetic patterns in-memory as `UIImage`s consumable by Stakka's
/// `ImageStacker` and star detector.
///
/// Pattern catalogue (mirrors the DSS test suite):
///
/// * `grayscale(width:height:background:bright:)` — uniform field + bright
///   pixels, used by `RegisterTest.cpp`.
/// * `block3x3`, `cross` — DSS "block of 9" / "cross of 3" shapes.
/// * `uniformGray(value:)` — constant field, used by `AvxAccumulateTest`
///   and `AvxHistogramTest` ("all pixels == N").
/// * `uniformColor(red:green:blue:)` — constant RGB field, used by
///   `AvxHistogramTest` ("R=55, G=66, B=77") and `AvxStackingTest`'s
///   "Three RGB frames".
/// * `horizontalGradient`, `verticalGradient` — ramps used by
///   `AvxCfaTest` to exercise Bilinear/AHD debayering and by
///   `AvxEntropyTest` for "all-values-different" entropy.
/// * `bayerMosaic(pattern:)` — CFA patterns (BGGR/GRBG/RGGB/GBRG) used by
///   `AvxCfaTest`.
/// * `hotPixel(at:)` — one-pixel outlier on a dark background, DSS
///   `RegisterTest` "hot pixel is not a star".
/// * `starField(stars:radius:)` — multiple 3x3 "stars" at arbitrary
///   coordinates on a dark background, for end-to-end stacking tests.
/// * `noisyField(background:noiseAmplitude:seed:)` — reproducible
///   pseudo-random field used to stress kappa-sigma / median outlier
///   rejection.
/// * `saturatedPlateau(rect:)` — wide bright rectangle (DSS "Rectangle
///   of 7x3 pixels no star").
/// * `twoStars(...)` — two well-separated or touching blobs, DSS's
///   multi-star / blob-merge scenarios.
/// * `mostlyUniformWithOutliers(...)` — DSS `AvxEntropyTest` "mostly
///   uniform but two bright outliers".
enum PatternImageFactory {
    /// A "bright pixel" specification matching DSS notation: `(x, y, value)`
    /// where `value` is in 0...255 luminance space.
    struct BrightPixel {
        let x: Int
        let y: Int
        let value: UInt8

        init(x: Int, y: Int, value: UInt8 = 200) {
            self.x = x
            self.y = y
            self.value = value
        }
    }

    /// Bayer colour filter array layouts supported by DSS's `AvxCfaTest`.
    enum BayerPattern {
        case rggb, bggr, grbg, gbrg
    }

    // MARK: - Grayscale primitive

    /// Render a grayscale `UIImage` with a uniform `background` luminance and
    /// optional `bright` pixels burned in at the given coordinates.
    static func grayscale(
        width: Int,
        height: Int,
        background: UInt8,
        bright: [BrightPixel] = []
    ) -> UIImage {
        var pixels = [UInt8](repeating: background, count: width * height)
        for pixel in bright {
            guard pixel.x >= 0, pixel.x < width, pixel.y >= 0, pixel.y < height else { continue }
            pixels[pixel.y * width + pixel.x] = pixel.value
        }
        return makeGrayImage(pixels: &pixels, width: width, height: height)
    }

    /// A 3x3 block (DSS "cross of 9") around the given center.
    static func block3x3(centerX: Int, centerY: Int, value: UInt8 = 200) -> [BrightPixel] {
        var pixels: [BrightPixel] = []
        for dy in -1...1 {
            for dx in -1...1 {
                pixels.append(BrightPixel(x: centerX + dx, y: centerY + dy, value: value))
            }
        }
        return pixels
    }

    /// A plus-shaped 5-pixel cross used by DSS RegisterTest "cross of 3 pixels".
    static func cross(centerX: Int, centerY: Int, value: UInt8 = 200) -> [BrightPixel] {
        [
            BrightPixel(x: centerX, y: centerY, value: value),
            BrightPixel(x: centerX - 1, y: centerY, value: value),
            BrightPixel(x: centerX + 1, y: centerY, value: value),
            BrightPixel(x: centerX, y: centerY - 1, value: value),
            BrightPixel(x: centerX, y: centerY + 1, value: value)
        ]
    }

    /// 2x2 block (DSS "Block of 4 pixels").
    static func block2x2(originX: Int, originY: Int, value: UInt8 = 200) -> [BrightPixel] {
        [
            BrightPixel(x: originX,     y: originY,     value: value),
            BrightPixel(x: originX + 1, y: originY,     value: value),
            BrightPixel(x: originX,     y: originY + 1, value: value),
            BrightPixel(x: originX + 1, y: originY + 1, value: value)
        ]
    }

    // MARK: - Uniform fields (AvxAccumulateTest, AvxHistogramTest)

    /// Constant grayscale field, the DSS "all pixels == N" scenario used
    /// by `AvxAccumulateTest` ("One/Two gray frames") and
    /// `AvxHistogramTest` ("CGrayBitmap all pixels == 100").
    static func uniformGray(
        width: Int = 256,
        height: Int = 32,
        value: UInt8
    ) -> UIImage {
        grayscale(width: width, height: height, background: value)
    }

    /// Constant RGB field, mirroring DSS `AvxHistogramTest`'s
    /// "R=55, G=66, B=77" and `AvxStackingTest`'s uniform RGB frames.
    static func uniformColor(
        width: Int = 256,
        height: Int = 32,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<(width * height) {
            pixels[index * 4]     = red
            pixels[index * 4 + 1] = green
            pixels[index * 4 + 2] = blue
            pixels[index * 4 + 3] = 255
        }
        return makeRGBAImage(pixels: &pixels, width: width, height: height)
    }

    // MARK: - Gradients (AvxCfaTest, AvxEntropyTest "all values different")

    /// Left-to-right grayscale ramp.  Equivalent to DSS's sequential
    /// `std::uint16_t` fill (`bitmap[i] = i`) scaled to 8-bit.
    static func horizontalGradient(width: Int = 64, height: Int = 8) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                pixels[y * width + x] = UInt8((x * 255) / max(1, width - 1))
            }
        }
        return makeGrayImage(pixels: &pixels, width: width, height: height)
    }

    /// Top-to-bottom grayscale ramp.
    static func verticalGradient(width: Int = 64, height: Int = 8) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            let value = UInt8((y * 255) / max(1, height - 1))
            for x in 0..<width {
                pixels[y * width + x] = value
            }
        }
        return makeGrayImage(pixels: &pixels, width: width, height: height)
    }

    /// Sequential gradient where every pixel has a distinct grayscale value
    /// (DSS `AvxEntropyTest` "all values different, starts at 3").  Only
    /// meaningful when `width * height <= 256`.
    static func sequentialGradient(width: Int = 16, height: Int = 16, start: UInt8 = 3) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: width * height)
        for index in 0..<(width * height) {
            pixels[index] = UInt8(truncatingIfNeeded: Int(start) + index)
        }
        return makeGrayImage(pixels: &pixels, width: width, height: height)
    }

    // MARK: - Bayer mosaics (AvxCfaTest)

    /// Encode a 2x2 Bayer tile on top of an RGB canvas, simulating the
    /// raw sensor mosaic input consumed by DSS's CFA interpolation tests.
    ///
    /// The output is an 8-bit RGBA bitmap where each pixel has only one
    /// non-zero channel depending on the `pattern`:
    ///
    /// * `.rggb` — row 0: R, G | row 1: G, B
    /// * `.bggr` — row 0: B, G | row 1: G, R
    /// * `.grbg` — row 0: G, R | row 1: B, G
    /// * `.gbrg` — row 0: G, B | row 1: R, G
    ///
    /// `intensity` controls the brightness of the filled channel; the two
    /// other channels are zero (matching DSS's "bitmap with only R/G/B
    /// pixels populated" fixtures).
    static func bayerMosaic(
        width: Int = 64,
        height: Int = 8,
        pattern: BayerPattern,
        intensity: UInt8 = 200
    ) -> UIImage {
        precondition(width % 2 == 0 && height % 2 == 0,
                     "Bayer mosaic dimensions must be even for a 2x2 tile.")
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        func channelIndex(row: Int, col: Int) -> Int {
            switch (pattern, row % 2, col % 2) {
            case (.rggb, 0, 0), (.bggr, 1, 1), (.grbg, 0, 1), (.gbrg, 1, 0): return 0 // R
            case (.rggb, 0, 1), (.rggb, 1, 0),
                 (.bggr, 0, 1), (.bggr, 1, 0),
                 (.grbg, 0, 0), (.grbg, 1, 1),
                 (.gbrg, 0, 0), (.gbrg, 1, 1): return 1 // G
            case (.rggb, 1, 1), (.bggr, 0, 0), (.grbg, 1, 0), (.gbrg, 0, 1): return 2 // B
            default: return 1
            }
        }

        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = (y * width + x) * 4
                pixels[pixelOffset + channelIndex(row: y, col: x)] = intensity
                pixels[pixelOffset + 3] = 255
            }
        }
        return makeRGBAImage(pixels: &pixels, width: width, height: height)
    }

    // MARK: - Hot pixel / outlier fixtures

    /// A single bright pixel on a dark background.  DSS's RegisterTest
    /// "Single pixel no star" fixture and a classic hot-pixel simulation.
    static func hotPixel(
        width: Int = 200,
        height: Int = 180,
        background: UInt8 = 10,
        at position: (x: Int, y: Int) = (105, 91),
        value: UInt8 = 220
    ) -> UIImage {
        grayscale(
            width: width,
            height: height,
            background: background,
            bright: [BrightPixel(x: position.x, y: position.y, value: value)]
        )
    }

    /// A dark field peppered with N scattered hot pixels — useful for
    /// verifying that single-pixel outliers are rejected by the detector
    /// (DSS RegisterTest "isolated pixels are never stars").
    static func hotPixelField(
        width: Int = 200,
        height: Int = 180,
        background: UInt8 = 12,
        positions: [(x: Int, y: Int)]
    ) -> UIImage {
        let bright = positions.map { BrightPixel(x: $0.x, y: $0.y, value: 230) }
        return grayscale(width: width, height: height, background: background, bright: bright)
    }

    // MARK: - Multi-star scenes

    /// Paint N simulated stars (each a 3x3 block) at the given locations
    /// on a dark grayscale canvas.  Mirrors DSS `RegisterTest`'s
    /// "block of 9 and block of 4 are 2 stars" family of fixtures.
    static func starField(
        width: Int = 200,
        height: Int = 180,
        background: UInt8 = 20,
        stars: [(x: Int, y: Int, value: UInt8)]
    ) -> UIImage {
        var bright: [BrightPixel] = []
        for star in stars {
            bright.append(contentsOf: block3x3(centerX: star.x, centerY: star.y, value: star.value))
        }
        return grayscale(width: width, height: height, background: background, bright: bright)
    }

    /// Two stars at configurable positions — convenience for DSS's
    /// "2 x 3 pixels are two stars" and "touching blobs merge" scenes.
    static func twoStars(
        width: Int = 200,
        height: Int = 180,
        background: UInt8 = 50,
        first: (x: Int, y: Int, value: UInt8) = (116, 97, 200),
        second: (x: Int, y: Int, value: UInt8) = (82, 115, 200),
        secondShape: BlobShape = .block2x2
    ) -> UIImage {
        var bright = block3x3(centerX: first.x, centerY: first.y, value: first.value)
        switch secondShape {
        case .block2x2:
            bright.append(contentsOf: block2x2(originX: second.x, originY: second.y, value: second.value))
        case .block3x3:
            bright.append(contentsOf: block3x3(centerX: second.x, centerY: second.y, value: second.value))
        case .cross:
            bright.append(contentsOf: cross(centerX: second.x, centerY: second.y, value: second.value))
        }
        return grayscale(width: width, height: height, background: background, bright: bright)
    }

    enum BlobShape { case block2x2, block3x3, cross }

    // MARK: - Saturated plateau (RegisterTest "Rectangle is no star")

    /// A wide uniformly bright rectangle on a darker background — DSS's
    /// "plateau with no local maxima" fixture.
    static func saturatedPlateau(
        width: Int = 200,
        height: Int = 180,
        background: UInt8 = 50,
        plateauRect: (x: Int, y: Int, width: Int, height: Int) = (114, 96, 7, 3),
        plateauValue: UInt8 = 180
    ) -> UIImage {
        var bright: [BrightPixel] = []
        for dy in 0..<plateauRect.height {
            for dx in 0..<plateauRect.width {
                bright.append(BrightPixel(
                    x: plateauRect.x + dx,
                    y: plateauRect.y + dy,
                    value: plateauValue
                ))
            }
        }
        return grayscale(width: width, height: height, background: background, bright: bright)
    }

    // MARK: - Noisy field (median / kappa-sigma robustness)

    /// Reproducible pseudo-random grayscale field.  Every pixel is
    /// `background ± noiseAmplitude` drawn from a linear-congruential PRNG
    /// seeded by `seed`.  Calling this twice with the same seed returns
    /// bit-identical data, which is what DSS uses when verifying median /
    /// kappa-sigma stackers converge under noise.
    static func noisyField(
        width: Int = 128,
        height: Int = 128,
        background: UInt8 = 40,
        noiseAmplitude: UInt8 = 6,
        seed: UInt64 = 0xDEAD_BEEF
    ) -> UIImage {
        var state = seed &* 0x9E37_79B9_7F4A_7C15 | 1
        var pixels = [UInt8](repeating: 0, count: width * height)
        for index in 0..<pixels.count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let offset = Int(Int8(bitPattern: UInt8(truncatingIfNeeded: state >> 56)))
            let scaled = Int(background) + offset / max(1, Int(128 / max(1, Int(noiseAmplitude))))
            pixels[index] = UInt8(clamping: scaled)
        }
        return makeGrayImage(pixels: &pixels, width: width, height: height)
    }

    // MARK: - Entropy fixtures (AvxEntropyTest)

    /// Mostly-uniform field with a few bright outliers.  Reproduces
    /// DSS `AvxEntropyTest`'s "most pixels == 555, two pixels == 7000 /
    /// 18000" scenario, scaled to 8-bit.
    static func mostlyUniformWithOutliers(
        width: Int = 256,
        height: Int = 64,
        background: UInt8 = 80,
        outliers: [BrightPixel] = [
            BrightPixel(x: 10, y: 10, value: 180),
            BrightPixel(x: 200, y: 40, value: 250)
        ]
    ) -> UIImage {
        grayscale(width: width, height: height, background: background, bright: outliers)
    }

    // MARK: - Private helpers

    private static func makeGrayImage(
        pixels: inout [UInt8],
        width: Int,
        height: Int
    ) -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ),
        let cgImage = context.makeImage() else {
            preconditionFailure("Failed to create grayscale CGContext for test pattern")
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private static func makeRGBAImage(
        pixels: inout [UInt8],
        width: Int,
        height: Int
    ) -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ),
        let cgImage = context.makeImage() else {
            preconditionFailure("Failed to create RGBA CGContext for test pattern")
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
