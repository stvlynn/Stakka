struct RunStackingUseCase: Sendable {
    private let processor: any StackingProcessor

    init(processor: any StackingProcessor) {
        self.processor = processor
    }

    func execute(
        project: StackingProject,
        progress: StackingProgressReporter? = nil
    ) async throws -> StackingResult {
        try await processor.stack(project, progress: progress)
    }
}
