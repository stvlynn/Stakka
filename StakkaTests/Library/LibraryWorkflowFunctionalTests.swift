import PhotosUI
import SwiftUI
import XCTest
@testable import Stakka

@MainActor
final class LibraryWorkflowFunctionalTests: XCTestCase {
    func testViewModelRunsAnalyzeRegisterStackAndPreparesTIFFExport() async throws {
        let lightA = StackFrame(
            kind: .light,
            name: "L-1",
            source: .fileURL(URL(fileURLWithPath: "/tmp/l1.png")),
            image: TestImageFactory.starField(stars: [CGPoint(x: 18, y: 22), CGPoint(x: 52, y: 49)])
        )
        let lightB = StackFrame(
            kind: .light,
            name: "L-2",
            source: .fileURL(URL(fileURLWithPath: "/tmp/l2.png")),
            image: TestImageFactory.starField(stars: [CGPoint(x: 18, y: 22), CGPoint(x: 52, y: 49)])
        )
        let processor = FakeStackingProcessor()
        let viewModel = makeViewModel(
            photoRepository: FakePhotoLibraryRepository(fileFrames: [lightA, lightB]),
            stackRepository: InMemoryStackProjectRepository(),
            processor: processor
        )

        await viewModel.importFrames(from: [URL(fileURLWithPath: "/tmp/l1.png")], kind: .light)
        viewModel.stack()

        await waitUntil { viewModel.phase == .idle && viewModel.result != nil }
        viewModel.prepareResultTIFFExport()

        XCTAssertEqual(viewModel.project.frames.count, 2)
        XCTAssertEqual(viewModel.result?.frameCount, 2)
        XCTAssertEqual(viewModel.pendingTIFFExport?.data, FakeStackingProcessor.tiffData)
        XCTAssertEqual(processor.stackCallCount, 1)
        XCTAssertTrue(viewModel.isPresentingTIFFExporter)
    }

    func testViewModelCometReviewEditingClearsAndRestoresReviewState() async throws {
        let frame = StackFrame(
            kind: .light,
            name: "Comet",
            source: .photoLibrary(assetIdentifier: "comet"),
            image: TestImageFactory.cometField(
                stars: [CGPoint(x: 18, y: 22), CGPoint(x: 52, y: 49)],
                cometCenter: CGPoint(x: 40, y: 44)
            )
        )
        let repository = InMemoryStackProjectRepository(project: StackingProject(
            cometMode: .cometOnly,
            frames: [frame],
            cometAnnotations: [
                frame.id: CometAnnotation(
                    estimatedPoint: PixelPoint(x: 40, y: 44),
                    resolvedPoint: nil,
                    confidence: 0.4,
                    isUserAdjusted: false,
                    requiresReview: true,
                    sourceFrameSize: PixelSize(width: frame.image.size.width, height: frame.image.size.height)
                )
            ]
        ))
        let viewModel = makeViewModel(
            photoRepository: FakePhotoLibraryRepository(),
            stackRepository: repository,
            processor: FakeStackingProcessor()
        )

        await viewModel.loadRecentProjectIfNeeded()
        viewModel.markCometPoint(PixelPoint(x: 42, y: 46), for: frame.id)
        let userAnnotation = try XCTUnwrap(viewModel.cometAnnotation(for: frame.id))

        XCTAssertEqual(userAnnotation.resolvedPoint, PixelPoint(x: 42, y: 46))
        XCTAssertTrue(userAnnotation.isUserAdjusted)
        XCTAssertFalse(userAnnotation.requiresReview)

        viewModel.restoreEstimatedCometPoint(for: frame.id)
        let restoredAnnotation = try XCTUnwrap(viewModel.cometAnnotation(for: frame.id))

        XCTAssertEqual(restoredAnnotation.resolvedPoint, PixelPoint(x: 40, y: 44))
        XCTAssertFalse(restoredAnnotation.isUserAdjusted)
        XCTAssertTrue(restoredAnnotation.requiresReview)
    }

    func testLocalProjectRepositoryRemovesOrphanedFrameImagesAndFallsBackRecentProject() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LocalStackProjectRepository(baseDirectoryURL: tempDirectory)
        let firstFrame = StackFrame(
            kind: .light,
            name: "L-1",
            source: .photoLibrary(assetIdentifier: "first"),
            image: TestImageFactory.starField(stars: [CGPoint(x: 18, y: 22)])
        )
        let secondFrame = StackFrame(
            kind: .light,
            name: "L-2",
            source: .photoLibrary(assetIdentifier: "second"),
            image: TestImageFactory.starField(stars: [CGPoint(x: 52, y: 49)])
        )
        var project = StackingProject(title: "Mutable", frames: [firstFrame, secondFrame])

        try await repository.save(project)
        project.frames = [firstFrame]
        try await repository.save(project)

        let framesDirectory = tempDirectory
            .appendingPathComponent("Stakka", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent(project.id.uuidString, isDirectory: true)
            .appendingPathComponent("Frames", isDirectory: true)
        let cachedFiles = try FileManager.default.contentsOfDirectory(atPath: framesDirectory.path())
        XCTAssertEqual(cachedFiles, ["\(firstFrame.id.uuidString).png"])

        let fallbackProject = StackingProject(title: "Fallback", frames: [firstFrame])
        try await repository.save(fallbackProject)
        try await repository.deleteProject(id: fallbackProject.id)

        let recentProject = try await repository.loadRecentProject()
        XCTAssertEqual(recentProject?.id, project.id)
    }

    private func makeViewModel(
        photoRepository: FakePhotoLibraryRepository,
        stackRepository: any StackProjectRepository,
        processor: FakeStackingProcessor
    ) -> LibraryStackingViewModel {
        LibraryStackingViewModel(
            importPhotos: ImportPhotosUseCase(repository: photoRepository),
            loadRecentProject: LoadRecentStackProjectUseCase(repository: stackRepository),
            loadProject: LoadStackProjectUseCase(repository: stackRepository),
            loadProjectSummaries: LoadStackProjectSummariesUseCase(repository: stackRepository),
            persistProject: PersistStackProjectUseCase(repository: stackRepository),
            clearRecentProject: ClearRecentStackProjectUseCase(repository: stackRepository),
            duplicateProject: DuplicateStackProjectUseCase(repository: stackRepository),
            deleteProject: DeleteStackProjectUseCase(repository: stackRepository),
            markRecentProject: MarkRecentStackProjectUseCase(repository: stackRepository),
            analyzeProject: AnalyzeStackProjectUseCase(processor: processor),
            registerProject: RegisterStackProjectUseCase(processor: processor),
            runStacking: RunStackingUseCase(processor: processor),
            exportStackedImage: ExportStackedImageUseCase(repository: photoRepository),
            prepareTIFFExport: PrepareStackedTIFFExportUseCase(),
            persistStackResult: PersistStackResultUseCase(repository: stackRepository),
            loadStackResult: LoadStackResultUseCase(repository: stackRepository)
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let startedAt = ContinuousClock.now

        while !condition() {
            if startedAt.duration(to: .now) > timeout {
                XCTFail("Timed out waiting for condition")
                return
            }

            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}

private struct FakePhotoLibraryRepository: PhotoLibraryRepository {
    var fileFrames: [StackFrame] = []

    func loadFrames(from items: [PhotosPickerItem], kind: StackFrameKind) async -> [StackFrame] {
        []
    }

    func loadFrames(from fileURLs: [URL], kind: StackFrameKind) async -> [StackFrame] {
        fileFrames.map { frame in
            StackFrame(
                id: frame.id,
                kind: kind,
                name: frame.name,
                source: frame.source,
                image: frame.image,
                isEnabled: frame.isEnabled,
                analysis: frame.analysis,
                registration: frame.registration
            )
        }
    }

    func save(image: UIImage) async throws {}
}

private actor InMemoryStackProjectRepository: StackProjectRepository {
    private var projects: [UUID: StackingProject]
    private var recentProjectID: UUID?
    private var resultImages: [UUID: UIImage] = [:]

    init(project: StackingProject? = nil) {
        if let project {
            projects = [project.id: project]
            recentProjectID = project.id
        } else {
            projects = [:]
            recentProjectID = nil
        }
    }

    func loadRecentProject() async throws -> StackingProject? {
        recentProjectID.flatMap { projects[$0] }
    }

    func loadProject(id: UUID) async throws -> StackingProject? {
        projects[id]
    }

    func loadResultImage(id: UUID) async throws -> UIImage? {
        resultImages[id]
    }

    func loadProjectSummaries() async throws -> [StackProjectSummary] {
        projects.values.map { project in
            StackProjectSummary(
                id: project.id,
                title: project.title,
                updatedAt: Date(),
                totalFrameCount: project.frames.count,
                lightFrameCount: project.enabledLightFrames.count,
                cometMode: project.cometMode,
                // In-memory stand-in: we can't surface a real file URL, but
                // a marker URL lets tests assert "project has result".
                resultThumbnailURL: resultImages[project.id] != nil
                    ? URL(string: "memory://\(project.id.uuidString)")
                    : nil
            )
        }
    }

    func save(_ project: StackingProject) async throws {
        projects[project.id] = project
        recentProjectID = project.id
    }

    func saveResult(_ image: UIImage, for projectID: UUID) async throws {
        resultImages[projectID] = image
    }

    func duplicateProject(id: UUID) async throws -> StackingProject {
        guard let project = projects[id] else {
            throw AppError.operationFailed("Missing project")
        }

        let duplicate = StackingProject(
            title: "\(project.title) Copy",
            mode: project.mode,
            cometMode: project.cometMode,
            frames: project.frames,
            cometAnnotations: project.cometAnnotations
        )
        projects[duplicate.id] = duplicate
        recentProjectID = duplicate.id
        return duplicate
    }

    func deleteProject(id: UUID) async throws {
        projects[id] = nil
        if recentProjectID == id {
            recentProjectID = projects.keys.first
        }
    }

    func markRecentProject(id: UUID) async throws {
        recentProjectID = id
    }

    func clearRecentProject() async throws {
        recentProjectID = nil
    }
}

private final class FakeStackingProcessor: StackingProcessor {
    static let tiffData = Data([0x49, 0x49, 0x2A, 0x00])

    private(set) var stackCallCount = 0

    func analyze(_ project: StackingProject, progress: StackingProgressReporter?) async throws -> StackingProject {
        _ = progress
        var project = project
        project.referenceFrameID = project.enabledLightFrames.first?.id
        project.frames = project.frames.map { frame in
            StackFrame(
                id: frame.id,
                kind: frame.kind,
                name: frame.name,
                source: frame.source,
                image: frame.image,
                isEnabled: frame.isEnabled,
                analysis: FrameAnalysis(starCount: 2, background: 0.1, fwhm: 1.4, score: 12),
                registration: frame.registration
            )
        }
        return project
    }

    func register(_ project: StackingProject, progress: StackingProgressReporter?) async throws -> StackingProject {
        var project = try await analyze(project, progress: progress)
        project.frames = project.frames.map { frame in
            StackFrame(
                id: frame.id,
                kind: frame.kind,
                name: frame.name,
                source: frame.source,
                image: frame.image,
                isEnabled: frame.isEnabled,
                analysis: frame.analysis,
                registration: frame.kind == .light
                    ? FrameRegistration(transform: .identity, confidence: 1, method: "reference")
                    : nil
            )
        }
        return project
    }

    func stack(_ project: StackingProject, progress: StackingProgressReporter?) async throws -> StackingResult {
        _ = progress
        stackCallCount += 1
        let image = TestImageFactory.starField(stars: [CGPoint(x: 24, y: 24), CGPoint(x: 48, y: 48)])
        return StackingResult(
            image: image,
            tiffData: Self.tiffData,
            frameCount: project.enabledLightFrames.count,
            mode: project.mode,
            recap: StackingRecap(
                referenceFrameName: project.enabledLightFrames.first?.name ?? "",
                usedLightFrameCount: project.enabledLightFrames.count,
                darkFrameCount: 0,
                flatFrameCount: 0,
                darkFlatFrameCount: 0,
                biasFrameCount: 0,
                cometMode: project.cometMode,
                annotatedFrameCount: project.cometAnnotations.count,
                manuallyAdjustedFrameCount: project.cometAnnotations.values.filter(\.isUserAdjusted).count
            )
        )
    }
}
