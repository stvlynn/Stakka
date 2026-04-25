import PhotosUI
import SwiftUI

struct ImportPhotosUseCase: Sendable {
    private let repository: any PhotoLibraryRepository

    init(repository: any PhotoLibraryRepository) {
        self.repository = repository
    }

    func execute(from items: [PhotosPickerItem], kind: StackFrameKind) async -> [StackFrame] {
        await repository.loadFrames(from: items, kind: kind)
    }

    func execute(from fileURLs: [URL], kind: StackFrameKind) async -> [StackFrame] {
        await repository.loadFrames(from: fileURLs, kind: kind)
    }
}
