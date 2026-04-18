struct LoadRecentStackProjectUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute() async throws -> StackingProject? {
        try await repository.loadRecentProject()
    }
}
