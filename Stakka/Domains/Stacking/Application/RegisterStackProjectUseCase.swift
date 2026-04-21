struct RegisterStackProjectUseCase {
    private let processor: any StackingProcessor

    init(processor: any StackingProcessor) {
        self.processor = processor
    }

    func execute(
        project: StackingProject,
        progress: StackingProgressReporter? = nil
    ) async throws -> StackingProject {
        try await processor.register(project, progress: progress)
    }
}
