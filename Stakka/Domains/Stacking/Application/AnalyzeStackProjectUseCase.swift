struct AnalyzeStackProjectUseCase {
    private let processor: any StackingProcessor

    init(processor: any StackingProcessor) {
        self.processor = processor
    }

    func execute(project: StackingProject) async throws -> StackingProject {
        try await processor.analyze(project)
    }
}
