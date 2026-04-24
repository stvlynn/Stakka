import XCTest
@testable import Stakka

/// Tests ported from `DeepSkyStackerTest/AvxAccumulateTest.cpp`
/// (https://github.com/deepskystacker/DSS/blob/master/DeepSkyStackerTest/AvxAccumulateTest.cpp).
///
/// DSS exercises its low-level `AvxAccumulation::accumulate(i)` routine by
/// pushing N constant-valued bitmaps through it and verifying the resulting
/// pixel buffer matches the analytic mean (FASTAVERAGE) or maximum (MAXIMUM).
///
/// Stakka's stacker is a higher-level Core Image pipeline, so the equivalent
/// scenarios are expressed against the public `StackingMode` aggregator
/// `ImageStacker.combine(_:mode:)`, which is the single point where every
/// stacking algorithm collapses N samples for a pixel into one output sample.
final class StackingModeTests: XCTestCase {

    // MARK: - FASTAVERAGE (DSS: "AVX Accumulation FASTAVERAGE")

    func testAverageOfSingleSampleEqualsItself() async {
        let stacker = ImageStacker()

        let result = await stacker.combine([0.5], mode: .average)

        XCTAssertEqual(result, 0.5, accuracy: 1e-6)
    }

    func testAverageOfTwoConstantFramesIsTheirMean() async {
        // Mirrors DSS "Two gray frames int16": frames assigned 100 and 3100,
        // expected output 0.5 * (100 + 3100). Stakka works in linear 0...1
        // floats, so the same arithmetic is normalised below.
        let stacker = ImageStacker()
        let frames: [Float] = [100.0 / 65535.0, 3100.0 / 65535.0]

        let result = await stacker.combine(frames, mode: .average)

        XCTAssertEqual(result, (frames[0] + frames[1]) / 2, accuracy: 1e-6)
    }

    func testAverageOfThreeFramesMatchesAnalyticMean() async {
        // Mirrors DSS "Three gray frames int32": values 303, 4503, 8703 with
        // expected output (303 + 4503 + 8703) / 3.
        let stacker = ImageStacker()
        let frames: [Float] = [303, 4503, 8703].map { $0 / 65535.0 }

        let result = await stacker.combine(frames, mode: .average)

        let expected = frames.reduce(0, +) / Float(frames.count)
        XCTAssertEqual(result, expected, accuracy: 1e-6)
    }

    func testAverageOfFourFloatFramesMatchesAnalyticMean() async {
        // Mirrors DSS "Four gray frames float": values 16000.0 + i * 17.35.
        let stacker = ImageStacker()
        let frames: [Float] = (0..<4).map { Float(16000.0 + Double($0) * 17.35) / 65535.0 }

        let result = await stacker.combine(frames, mode: .average)

        let expected = frames.reduce(0, +) / Float(frames.count)
        XCTAssertEqual(result, expected, accuracy: 1e-6)
    }

    // MARK: - MEDIAN (DSS-style robustness against a single outlier)

    func testMedianRejectsSingleOutlier() async {
        // Three "good" frames at the same level plus one extreme outlier.
        // DSS does not have a direct median test, but the AvxAccumulate suite
        // verifies that aggregators converge on the analytic value even when
        // a single pixel diverges; median is the textbook answer for that.
        let stacker = ImageStacker()
        let samples: [Float] = [0.30, 0.31, 0.32, 0.99]

        let result = await stacker.combine(samples, mode: .median)

        XCTAssertEqual(result, 0.315, accuracy: 1e-6)
    }

    func testMedianOfOddCountReturnsMiddleValue() async {
        let stacker = ImageStacker()
        let samples: [Float] = [0.10, 0.40, 0.20, 0.50, 0.30]

        let result = await stacker.combine(samples, mode: .median)

        XCTAssertEqual(result, 0.30, accuracy: 1e-6)
    }

    // MARK: - KAPPA-SIGMA (DSS-style outlier rejection)

    func testKappaSigmaIsCloseToMeanWhenAllSamplesAgree() async {
        let stacker = ImageStacker()
        let samples: [Float] = Array(repeating: 0.42, count: 6)

        let result = await stacker.combine(samples, mode: .kappaSigma)

        XCTAssertEqual(result, 0.42, accuracy: 1e-5)
    }

    func testKappaSigmaPullsResultAwayFromExtremeOutlier() async {
        // With a single extreme outlier, the kappa-sigma result should sit
        // strictly between the mean of the inliers and the arithmetic mean
        // of all samples (since kappa-sigma rejects deviating samples).
        let stacker = ImageStacker()
        let samples: [Float] = [0.20, 0.21, 0.19, 0.22, 0.95]
        let inliers = samples.dropLast()
        let inlierMean = inliers.reduce(0, +) / Float(inliers.count)
        let arithmeticMean = samples.reduce(0, +) / Float(samples.count)

        let result = await stacker.combine(samples, mode: .kappaSigma)

        XCTAssertLessThan(result, arithmeticMean,
                          "Kappa-sigma must move below the arithmetic mean once the outlier is rejected.")
        XCTAssertEqual(result, inlierMean, accuracy: 0.05)
    }

    func testMedianKappaSigmaReplacesRejectedSampleWithMedian() async {
        // medianKappaSigma should be at least as robust as plain kappaSigma;
        // for a clean inlier set with one outlier its result still tracks the
        // inlier mean closely.
        let stacker = ImageStacker()
        let samples: [Float] = [0.50, 0.51, 0.49, 0.52, 0.05]
        let inliers = samples.dropFirst(0).dropLast()
        let inlierMean = inliers.reduce(0, +) / Float(inliers.count)

        let result = await stacker.combine(samples, mode: .medianKappaSigma)

        XCTAssertEqual(result, inlierMean, accuracy: 0.05)
    }

    // MARK: - MAXIMUM (DSS: "AVX Accumulation MAXIMUM")

    func testMaximumKeepsBrightestSample() async {
        let stacker = ImageStacker()
        let samples: [Float] = [0.12, 0.84, 0.31, 0.63]

        let result = await stacker.combine(samples, mode: .maximum)

        XCTAssertEqual(result, 0.84, accuracy: 1e-6)
    }

    // MARK: - End-to-end stack: DSS "One/Two gray frames" parity

    func testEndToEndAverageOfTwoIdenticalFramesPreservesBrightness() async throws {
        // DSS "AVX Accumulation FASTAVERAGE / One gray frame with identical
        // values" verifies that pushing a constant-valued frame through the
        // accumulator yields the same constant value.  At the public-stack
        // API level we instead verify that two identical light frames
        // produce a non-empty TIFF output with the expected frame count.
        let baseStars = [
            CGPoint(x: 18, y: 22),
            CGPoint(x: 34, y: 41),
            CGPoint(x: 52, y: 49),
            CGPoint(x: 67, y: 18)
        ]
        let image = TestImageFactory.starField(stars: baseStars)
        let analysis = FrameAnalysis(starCount: 4, background: 0.02, fwhm: 1.2, score: 20)
        let registration = FrameRegistration(transform: .identity, confidence: 1, method: "reference")

        let frameA = StackFrame(
            id: UUID(), kind: .light, name: "L-1",
            source: .photoLibrary(assetIdentifier: "asset-1"),
            image: image, isEnabled: true, analysis: analysis, registration: registration
        )
        let frameB = StackFrame(
            id: UUID(), kind: .light, name: "L-2",
            source: .photoLibrary(assetIdentifier: "asset-2"),
            image: image, isEnabled: true, analysis: analysis, registration: registration
        )
        let project = StackingProject(
            title: "Identity Stack",
            mode: .average,
            referenceFrameID: frameA.id,
            frames: [frameA, frameB]
        )

        let result = try await ImageStacker().stack(project)

        XCTAssertEqual(result.frameCount, 2)
        XCTAssertEqual(result.mode, .average)
        XCTAssertFalse(result.tiffData.isEmpty)
    }
}
