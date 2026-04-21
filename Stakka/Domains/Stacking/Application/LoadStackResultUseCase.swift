import UIKit

/// Reads a previously persisted result image. Used by the gallery preview
/// to show the stacked output at full size without having to re-run the
/// pipeline.
struct LoadStackResultUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute(projectID: UUID) async throws -> UIImage? {
        try await repository.loadResultImage(id: projectID)
    }
}
