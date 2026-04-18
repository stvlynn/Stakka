import Foundation

struct MarkRecentStackProjectUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws {
        try await repository.markRecentProject(id: id)
    }
}
