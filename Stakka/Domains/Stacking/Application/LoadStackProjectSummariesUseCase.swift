struct LoadStackProjectSummariesUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute() async throws -> [StackProjectSummary] {
        try await repository.loadProjectSummaries()
    }
}
