import Foundation

struct ReplaceRecentStackProjectWithCapturedFramesUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute(frames: [CaptureFrame]) async throws -> StackingProject {
        let projectFrames = frames.enumerated().map { index, frame in
            StackFrame(
                kind: .light,
                name: L10n.Project.captureFrameName(index: index + 1),
                source: .capture(identifier: frame.id.uuidString),
                image: frame.image
            )
        }

        let titleTime = frames.first?.capturedAt ?? Date()
        let project = StackingProject(
            title: L10n.Project.captureTitle(at: titleTime),
            mode: .average,
            cometMode: nil,
            frames: projectFrames
        )

        try await repository.save(project)
        return project
    }

    func execute(project: StackingProject) async throws -> StackingProject {
        try await repository.save(project)
        return project
    }
}
