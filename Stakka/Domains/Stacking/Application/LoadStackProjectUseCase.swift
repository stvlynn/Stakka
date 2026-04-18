import Foundation

struct LoadStackProjectUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws -> StackingProject? {
        try await repository.loadProject(id: id)
    }
}
