import Foundation

struct DuplicateStackProjectUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws -> StackingProject {
        try await repository.duplicateProject(id: id)
    }
}
