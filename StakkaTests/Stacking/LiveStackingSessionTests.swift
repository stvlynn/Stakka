import XCTest
@testable import Stakka

final class LiveStackingSessionTests: XCTestCase {
    func testStarTrailSessionStacksEachFrameWithoutRegistration() async throws {
        let session = ImageLiveStackingSession(stacker: ImageStacker())
        await session.reset(configuration: LiveStackingConfiguration(
            strategy: .starTrails,
            title: "Star Trails",
            exposureTime: 30
        ))

        let first = PatternImageFactory.uniformGray(width: 32, height: 32, value: 40)
        let second = PatternImageFactory.uniformGray(width: 32, height: 32, value: 180)

        let firstSnapshot = await session.addFrame(
            image: first,
            name: "L-1",
            source: .capture(identifier: "1"),
            capturedAt: Date(),
            exposureDuration: 10
        )
        XCTAssertEqual(firstSnapshot.acceptedFrameCount, 1)
        XCTAssertEqual(firstSnapshot.phase, .waitingForFrames)

        let secondSnapshot = await session.addFrame(
            image: second,
            name: "L-2",
            source: .capture(identifier: "2"),
            capturedAt: Date(),
            exposureDuration: 30
        )
        XCTAssertEqual(secondSnapshot.acceptedFrameCount, 2)
        XCTAssertEqual(secondSnapshot.rejectedFrameCount, 0)
        XCTAssertEqual(secondSnapshot.phase, .stacking)
        XCTAssertEqual(secondSnapshot.totalExposure, 40)
        XCTAssertNotNil(secondSnapshot.previewImage)

        let project = await session.currentProject()
        XCTAssertEqual(project?.frames.count, 2)
        XCTAssertEqual(project?.mode, .maximum)
        XCTAssertEqual(project?.frames.compactMap(\.registration?.method), ["fixed-tripod", "fixed-tripod"])
    }

    func testDeepSkySessionWaitsForTwoFramesBeforeRenderingPreview() async throws {
        let session = ImageLiveStackingSession(stacker: ImageStacker())
        await session.reset(configuration: LiveStackingConfiguration(
            strategy: .deepSky,
            title: "Milky Way",
            exposureTime: 15
        ))

        let image = TestImageFactory.starField(stars: [
            CGPoint(x: 12, y: 14),
            CGPoint(x: 22, y: 24),
            CGPoint(x: 34, y: 36)
        ])

        let snapshot = await session.addFrame(
            image: image,
            name: "L-1",
            source: .capture(identifier: "1"),
            capturedAt: Date(),
            exposureDuration: 15
        )

        XCTAssertEqual(snapshot.acceptedFrameCount, 1)
        XCTAssertEqual(snapshot.phase, .waitingForFrames)
        XCTAssertNotNil(snapshot.previewImage)
        let project = await session.currentProject()
        XCTAssertNil(project?.referenceFrameID)
    }
}
