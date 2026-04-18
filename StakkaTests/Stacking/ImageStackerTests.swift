import XCTest
@testable import Stakka

final class ImageStackerTests: XCTestCase {
    func testStackProducesImageAndTIFFData() async throws {
        let baseStars = [
            CGPoint(x: 18, y: 22),
            CGPoint(x: 34, y: 41),
            CGPoint(x: 52, y: 49),
            CGPoint(x: 67, y: 18)
        ]
        let imageA = TestImageFactory.starField(stars: baseStars)
        let imageB = TestImageFactory.starField(stars: baseStars, offset: CGSize(width: 1, height: 0))

        let registrationIdentity = FrameRegistration(
            transform: .identity,
            confidence: 1,
            method: "reference"
        )
        let registrationShift = FrameRegistration(
            transform: ProjectiveTransform(
                m11: 1, m12: 0, m13: -1,
                m21: 0, m22: 1, m23: 0,
                m31: 0, m32: 0, m33: 1
            ),
            confidence: 1,
            method: "translation"
        )

        let analysis = FrameAnalysis(starCount: 4, background: 0.02, fwhm: 1.2, score: 20)
        let frameA = StackFrame(
            id: UUID(),
            kind: .light,
            name: "L-1",
            source: .photoLibrary(assetIdentifier: "asset-1"),
            image: imageA,
            isEnabled: true,
            analysis: analysis,
            registration: registrationIdentity
        )
        let frameB = StackFrame(
            id: UUID(),
            kind: .light,
            name: "L-2",
            source: .photoLibrary(assetIdentifier: "asset-2"),
            image: imageB,
            isEnabled: true,
            analysis: analysis,
            registration: registrationShift
        )
        let project = StackingProject(
            title: "Stack Test",
            mode: .average,
            referenceFrameID: frameA.id,
            frames: [frameA, frameB]
        )

        let result = try await ImageStacker().stack(project)

        XCTAssertEqual(result.frameCount, 2)
        XCTAssertFalse(result.tiffData.isEmpty)
        XCTAssertGreaterThan(result.image.size.width, 0)
        XCTAssertEqual(result.recap.referenceFrameName, "L-1")
    }

    func testCometModesProduceResultsWhenAnnotationsArePresent() async throws {
        let stars = [
            CGPoint(x: 18, y: 22),
            CGPoint(x: 34, y: 41),
            CGPoint(x: 52, y: 49),
            CGPoint(x: 67, y: 18)
        ]
        let frameAImage = TestImageFactory.cometField(stars: stars, cometCenter: CGPoint(x: 28, y: 54))
        let frameBImage = TestImageFactory.cometField(stars: stars, cometCenter: CGPoint(x: 42, y: 54))
        let analysis = FrameAnalysis(starCount: 4, background: 0.03, fwhm: 1.3, score: 22)

        let frameA = StackFrame(
            id: UUID(),
            kind: .light,
            name: "L-1",
            source: .photoLibrary(assetIdentifier: "asset-1"),
            image: frameAImage,
            isEnabled: true,
            analysis: analysis,
            registration: FrameRegistration(transform: .identity, confidence: 1, method: "reference")
        )
        let frameB = StackFrame(
            id: UUID(),
            kind: .light,
            name: "L-2",
            source: .photoLibrary(assetIdentifier: "asset-2"),
            image: frameBImage,
            isEnabled: true,
            analysis: analysis,
            registration: FrameRegistration(transform: .identity, confidence: 1, method: "translation")
        )

        for cometMode in CometStackingMode.allCases {
            let project = StackingProject(
                title: "Comet Test",
                mode: .average,
                cometMode: cometMode,
                referenceFrameID: frameA.id,
                frames: [frameA, frameB],
                cometAnnotations: [
                    frameA.id: CometAnnotation(
                        estimatedPoint: PixelPoint(x: 28, y: 54),
                        resolvedPoint: PixelPoint(x: 28, y: 54),
                        confidence: 1,
                        isUserAdjusted: false,
                        requiresReview: false,
                        sourceFrameSize: PixelSize(width: frameAImage.size.width, height: frameAImage.size.height)
                    ),
                    frameB.id: CometAnnotation(
                        estimatedPoint: PixelPoint(x: 42, y: 54),
                        resolvedPoint: PixelPoint(x: 42, y: 54),
                        confidence: 1,
                        isUserAdjusted: false,
                        requiresReview: false,
                        sourceFrameSize: PixelSize(width: frameBImage.size.width, height: frameBImage.size.height)
                    )
                ]
            )

            let result = try await ImageStacker().stack(project)
            XCTAssertFalse(result.tiffData.isEmpty)
            XCTAssertEqual(result.recap.cometMode, cometMode)
            XCTAssertEqual(result.recap.annotatedFrameCount, 2)
        }
    }
}
