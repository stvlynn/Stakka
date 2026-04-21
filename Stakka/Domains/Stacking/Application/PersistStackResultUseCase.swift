import UIKit

/// Writes the stacked image produced by the pipeline to the project store
/// so the gallery can list completed projects with their result as the
/// tile thumbnail.
struct PersistStackResultUseCase {
    private let repository: any StackProjectRepository

    init(repository: any StackProjectRepository) {
        self.repository = repository
    }

    func execute(image: UIImage, projectID: UUID) async throws {
        try await repository.saveResult(image, for: projectID)
    }
}
