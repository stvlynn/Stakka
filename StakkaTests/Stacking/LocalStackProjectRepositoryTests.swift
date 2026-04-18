import XCTest
@testable import Stakka

final class LocalStackProjectRepositoryTests: XCTestCase {
    func testRecentProjectRoundTripRestoresFramesAndMetadata() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LocalStackProjectRepository(baseDirectoryURL: tempDirectory)
        let image = TestImageFactory.starField(stars: [CGPoint(x: 18, y: 22), CGPoint(x: 52, y: 49)])
        let cometAnnotation = CometAnnotation(
            estimatedPoint: PixelPoint(x: 40, y: 32),
            resolvedPoint: PixelPoint(x: 42, y: 31),
            confidence: 0.82,
            isUserAdjusted: true,
            requiresReview: false,
            sourceFrameSize: PixelSize(width: image.size.width, height: image.size.height)
        )
        let frameID = UUID()
        let project = StackingProject(
            title: "Round Trip",
            mode: .medianKappaSigma,
            cometMode: .cometAndStars,
            referenceFrameID: nil,
            frames: [
                StackFrame(
                    id: frameID,
                    kind: .light,
                    name: "L-1",
                    source: .photoLibrary(assetIdentifier: "asset-1"),
                    image: image,
                    isEnabled: true,
                    analysis: FrameAnalysis(starCount: 12, background: 0.1, fwhm: 1.8, score: 88.2),
                    registration: FrameRegistration(
                        transform: ProjectiveTransform(
                            m11: 1, m12: 0, m13: 4,
                            m21: 0, m22: 1, m23: -2,
                            m31: 0, m32: 0, m33: 1
                        ),
                        confidence: 0.9,
                        method: "translation"
                    )
                )
            ],
            cometAnnotations: [frameID: cometAnnotation]
        )

        try await repository.save(project)
        let restoredProject = try await repository.loadRecentProject()

        XCTAssertEqual(restoredProject?.title, "Round Trip")
        XCTAssertEqual(restoredProject?.mode, .medianKappaSigma)
        XCTAssertEqual(restoredProject?.cometMode, .cometAndStars)
        XCTAssertEqual(restoredProject?.frames.count, 1)
        XCTAssertEqual(restoredProject?.frames.first?.name, "L-1")
        XCTAssertEqual(restoredProject?.frames.first?.analysis?.starCount, 12)
        XCTAssertEqual(restoredProject?.frames.first?.registration?.method, "translation")
        XCTAssertEqual(restoredProject?.cometAnnotations.values.first?.isUserAdjusted, true)
        XCTAssertEqual(
            try XCTUnwrap(restoredProject?.frames.first?.registration?.transform.translationX),
            4,
            accuracy: 0.001
        )
    }

    func testProjectCatalogSupportsListDuplicateAndDelete() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LocalStackProjectRepository(baseDirectoryURL: tempDirectory)
        let image = TestImageFactory.starField(stars: [CGPoint(x: 20, y: 20)])

        let firstProject = StackingProject(
            title: "First",
            frames: [
                StackFrame(
                    kind: .light,
                    name: "L-1",
                    source: .photoLibrary(assetIdentifier: "first"),
                    image: image
                )
            ]
        )

        let secondProject = StackingProject(
            title: "Second",
            cometMode: .standard,
            frames: [
                StackFrame(
                    kind: .light,
                    name: "L-2",
                    source: .photoLibrary(assetIdentifier: "second"),
                    image: image
                )
            ]
        )

        try await repository.save(firstProject)
        try await repository.save(secondProject)

        var summaries = try await repository.loadProjectSummaries()
        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries.first?.title, "Second")
        XCTAssertEqual(summaries.first?.cometMode, .standard)

        let duplicate = try await repository.duplicateProject(id: firstProject.id)
        XCTAssertEqual(duplicate.title, "First 副本")

        summaries = try await repository.loadProjectSummaries()
        XCTAssertEqual(summaries.count, 3)

        try await repository.deleteProject(id: secondProject.id)
        summaries = try await repository.loadProjectSummaries()
        XCTAssertEqual(summaries.count, 2)
        XCTAssertFalse(summaries.contains(where: { $0.id == secondProject.id }))
    }
}
