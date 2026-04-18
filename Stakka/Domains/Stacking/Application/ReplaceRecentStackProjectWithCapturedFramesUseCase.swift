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
                name: "Capture-\(index + 1)",
                source: .capture(identifier: frame.id.uuidString),
                image: frame.image
            )
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let titleTime = frames.first?.capturedAt ?? Date()
        let project = StackingProject(
            title: "拍摄工程 \(formatter.string(from: titleTime))",
            mode: .average,
            cometMode: nil,
            frames: projectFrames
        )

        try await repository.save(project)
        return project
    }
}
