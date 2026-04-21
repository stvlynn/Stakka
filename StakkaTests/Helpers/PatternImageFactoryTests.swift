import UIKit
import XCTest
@testable import Stakka

/// Smoke tests for the DSS-derived test-image fixtures in `PatternImageFactory`.
///
/// These do *not* test Stakka's stacking pipeline; they verify that every
/// synthetic pattern ported from the DeepSkyStacker test suite
/// (https://github.com/deepskystacker/DSS) actually produces a well-formed
/// `UIImage` of the expected dimensions and pixel profile, so that higher-
/// level parity tests (`RegisterTests`, `StackingModeTests`, etc.) can rely
/// on them without rediscovering rendering bugs.
final class PatternImageFactoryTests: XCTestCase {

    // MARK: - Uniform fields (AvxAccumulateTest / AvxHistogramTest)

    func testUniformGrayHasExactDimensions() {
        let image = PatternImageFactory.uniformGray(width: 128, height: 24, value: 100)
        XCTAssertEqual(Int(image.size.width), 128)
        XCTAssertEqual(Int(image.size.height), 24)
    }

    func testUniformGrayPixelValueIsConstant() throws {
        let image = PatternImageFactory.uniformGray(width: 32, height: 8, value: 123)
        let samples = try grayscaleSamples(of: image)
        XCTAssertTrue(samples.allSatisfy { $0 == 123 },
                      "DSS 'all pixels == N' fixture must have no pixel variance.")
    }

    func testUniformColorEncodesAllThreeChannelsIndependently() throws {
        let image = PatternImageFactory.uniformColor(
            width: 16, height: 16, red: 55, green: 66, blue: 77
        )
        let (r, g, b) = try firstRGBSample(of: image)
        XCTAssertEqual(r, 55)
        XCTAssertEqual(g, 66)
        XCTAssertEqual(b, 77)
    }

    // MARK: - Gradients (AvxCfaTest / AvxEntropyTest)

    func testHorizontalGradientStartsDarkAndEndsBright() throws {
        let image = PatternImageFactory.horizontalGradient(width: 32, height: 4)
        let samples = try grayscaleSamples(of: image)
        XCTAssertEqual(samples.first, 0)
        XCTAssertEqual(samples[31], 255)
    }

    func testVerticalGradientIsConstantAcrossRowsAndMonotonicDown() throws {
        let width = 16
        let height = 8
        let image = PatternImageFactory.verticalGradient(width: width, height: height)
        let samples = try grayscaleSamples(of: image)

        for y in 0..<height {
            let row = Array(samples[(y * width)..<((y + 1) * width)])
            XCTAssertEqual(Set(row).count, 1, "Every row of a vertical gradient must be constant.")
        }
        XCTAssertLessThan(samples[0], samples[samples.count - 1])
    }

    func testSequentialGradientProducesDistinctValues() throws {
        let image = PatternImageFactory.sequentialGradient(width: 8, height: 8, start: 3)
        let samples = try grayscaleSamples(of: image)
        XCTAssertEqual(samples.count, 64)
        XCTAssertEqual(Set(samples).count, 64,
                       "DSS entropy 'all values different' fixture must have 64 unique samples.")
    }

    // MARK: - Bayer mosaics (AvxCfaTest)

    func testRGGBBayerMosaicPlacesRedAtEvenRowsAndColumns() throws {
        let image = PatternImageFactory.bayerMosaic(
            width: 8, height: 8, pattern: .rggb, intensity: 200
        )
        let samples = try rgbaSamples(of: image)

        // RGGB: (0, 0) is red, (0, 1) is green, (1, 1) is blue.
        let redAt00 = pixel(samples, x: 0, y: 0, width: 8)
        XCTAssertEqual(redAt00.r, 200)
        XCTAssertEqual(redAt00.g, 0)
        XCTAssertEqual(redAt00.b, 0)

        let greenAt01 = pixel(samples, x: 1, y: 0, width: 8)
        XCTAssertEqual(greenAt01.g, 200)
        XCTAssertEqual(greenAt01.r, 0)
        XCTAssertEqual(greenAt01.b, 0)

        let blueAt11 = pixel(samples, x: 1, y: 1, width: 8)
        XCTAssertEqual(blueAt11.b, 200)
        XCTAssertEqual(blueAt11.r, 0)
        XCTAssertEqual(blueAt11.g, 0)
    }

    func testBGGRBayerMosaicPlacesBlueAtOrigin() throws {
        let image = PatternImageFactory.bayerMosaic(
            width: 4, height: 4, pattern: .bggr, intensity: 180
        )
        let samples = try rgbaSamples(of: image)
        let topLeft = pixel(samples, x: 0, y: 0, width: 4)
        XCTAssertEqual(topLeft.b, 180)
        XCTAssertEqual(topLeft.r, 0)
    }

    // MARK: - Hot pixel / multi-star scenes

    func testHotPixelFieldOnlyTouchesRequestedPositions() throws {
        let positions: [(x: Int, y: Int)] = [(5, 5), (50, 60), (199, 179)]
        let image = PatternImageFactory.hotPixelField(
            width: 200, height: 180, background: 12, positions: positions
        )
        let samples = try grayscaleSamples(of: image)

        for position in positions {
            let value = samples[position.y * 200 + position.x]
            XCTAssertEqual(value, 230,
                           "Hot pixel at (\(position.x), \(position.y)) must be set.")
        }
        // Any pixel not listed must still be at background level.
        XCTAssertEqual(samples[0], 12)
        XCTAssertEqual(samples[100 * 200 + 100], 12)
    }

    func testStarFieldPlacesOneBlockPerStar() throws {
        let image = PatternImageFactory.starField(
            width: 60, height: 60, background: 10,
            stars: [(x: 10, y: 10, value: 200), (x: 40, y: 40, value: 180)]
        )
        let samples = try grayscaleSamples(of: image)

        XCTAssertEqual(samples[10 * 60 + 10], 200)
        XCTAssertEqual(samples[40 * 60 + 40], 180)
        // Centre pixel between the two stars stays background.
        XCTAssertEqual(samples[25 * 60 + 25], 10)
    }

    func testSaturatedPlateauFillsTheExpectedRectangle() throws {
        let image = PatternImageFactory.saturatedPlateau(
            width: 40, height: 20,
            background: 0,
            plateauRect: (x: 10, y: 5, width: 4, height: 3),
            plateauValue: 255
        )
        let samples = try grayscaleSamples(of: image)

        for y in 5..<8 {
            for x in 10..<14 {
                XCTAssertEqual(samples[y * 40 + x], 255, "Plateau pixel (\(x),\(y)) must be saturated.")
            }
        }
        XCTAssertEqual(samples[0], 0)
    }

    // MARK: - Deterministic noise (kappa-sigma / median)

    func testNoisyFieldIsDeterministicForTheSameSeed() throws {
        let imageA = PatternImageFactory.noisyField(width: 32, height: 32, seed: 1)
        let imageB = PatternImageFactory.noisyField(width: 32, height: 32, seed: 1)
        let samplesA = try grayscaleSamples(of: imageA)
        let samplesB = try grayscaleSamples(of: imageB)
        XCTAssertEqual(samplesA, samplesB,
                       "Reusing the same seed must produce identical DSS noise fixtures.")
    }

    func testNoisyFieldsWithDifferentSeedsDiffer() throws {
        let imageA = PatternImageFactory.noisyField(width: 32, height: 32, seed: 1)
        let imageB = PatternImageFactory.noisyField(width: 32, height: 32, seed: 2)
        let samplesA = try grayscaleSamples(of: imageA)
        let samplesB = try grayscaleSamples(of: imageB)
        XCTAssertNotEqual(samplesA, samplesB)
    }

    func testMostlyUniformWithOutliersKeepsBackgroundDominant() throws {
        let image = PatternImageFactory.mostlyUniformWithOutliers(
            width: 64, height: 32, background: 80,
            outliers: [PatternImageFactory.BrightPixel(x: 5, y: 5, value: 250)]
        )
        let samples = try grayscaleSamples(of: image)
        let backgroundCount = samples.filter { $0 == 80 }.count
        XCTAssertEqual(backgroundCount, 64 * 32 - 1)
        XCTAssertEqual(samples[5 * 64 + 5], 250)
    }

    // MARK: - Helpers

    /// Read the raw 8-bit single-channel samples from a grayscale `UIImage`.
    private func grayscaleSamples(of image: UIImage) throws -> [UInt8] {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var samples = [UInt8](repeating: 0, count: width * height)
        let context = CGContext(
            data: &samples,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return samples
    }

    private func rgbaSamples(of image: UIImage) throws -> [UInt8] {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var samples = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &samples,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return samples
    }

    private func firstRGBSample(of image: UIImage) throws -> (r: UInt8, g: UInt8, b: UInt8) {
        let samples = try rgbaSamples(of: image)
        return (samples[0], samples[1], samples[2])
    }

    private func pixel(
        _ samples: [UInt8],
        x: Int,
        y: Int,
        width: Int
    ) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let offset = (y * width + x) * 4
        return (samples[offset], samples[offset + 1], samples[offset + 2], samples[offset + 3])
    }
}
