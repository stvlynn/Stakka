struct ClearRecentStackProjectUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute() async throws {
        try await repository.clearRecentProject()
    }
}
