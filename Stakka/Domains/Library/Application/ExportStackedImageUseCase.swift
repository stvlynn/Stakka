import UIKit

struct ExportStackedImageUseCase {
    private let repository: PhotoLibraryRepository

    init(repository: PhotoLibraryRepository) {
        self.repository = repository
    }

    func execute(image: UIImage) async throws {
        try await repository.save(image: image)
    }
}
