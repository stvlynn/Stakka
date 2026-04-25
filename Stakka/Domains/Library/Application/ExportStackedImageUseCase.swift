import UIKit

struct ExportStackedImageUseCase: Sendable {
    private let repository: any PhotoLibraryRepository

    init(repository: any PhotoLibraryRepository) {
        self.repository = repository
    }

    func execute(image: UIImage) async throws {
        try await repository.save(image: image)
    }
}
