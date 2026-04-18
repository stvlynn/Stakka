import PhotosUI
import SwiftUI

struct ImportPhotosUseCase {
    private let repository: PhotoLibraryRepository

    init(repository: PhotoLibraryRepository) {
        self.repository = repository
    }

    func execute(from items: [PhotosPickerItem]) async -> [ImportedImage] {
        await repository.loadImages(from: items)
    }
}
