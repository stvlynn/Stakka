struct PersistStackProjectUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute(project: StackingProject) async throws {
        try await repository.save(project)
    }
}
