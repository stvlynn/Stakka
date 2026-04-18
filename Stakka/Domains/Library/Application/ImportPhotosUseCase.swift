import PhotosUI
import SwiftUI

struct ImportPhotosUseCase {
    private let repository: PhotoLibraryRepository

    init(repository: PhotoLibraryRepository) {
        self.repository = repository
    }

    func execute(from items: [PhotosPickerItem], kind: StackFrameKind) async -> [StackFrame] {
        await repository.loadFrames(from: items, kind: kind)
    }

    func execute(from fileURLs: [URL], kind: StackFrameKind) async -> [StackFrame] {
        await repository.loadFrames(from: fileURLs, kind: kind)
    }
}
