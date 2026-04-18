import Combine
import PhotosUI
import SwiftUI

@MainActor
final class LibraryStackingViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published private(set) var selectedImages: [ImportedImage] = []
    @Published private(set) var isStacking = false
    @Published private(set) var stackedImage: UIImage?

    private let importPhotos: ImportPhotosUseCase
    private let runStacking: RunStackingUseCase
    private let exportStackedImage: ExportStackedImageUseCase
    private var cancellables = Set<AnyCancellable>()

    init(
        importPhotos: ImportPhotosUseCase,
        runStacking: RunStackingUseCase,
        exportStackedImage: ExportStackedImageUseCase
    ) {
        self.importPhotos = importPhotos
        self.runStacking = runStacking
        self.exportStackedImage = exportStackedImage
        observeSelectedItems()
    }

    func clearSelection() {
        withAnimation(AnimationPreset.smooth) {
            selectedItems.removeAll()
            selectedImages.removeAll()
            stackedImage = nil
        }
    }

    func stackImages() {
        guard !selectedImages.isEmpty else { return }
        isStacking = true

        Task {
            defer { isStacking = false }

            if let result = try? await runStacking.execute(images: selectedImages.map(\.image)) {
                stackedImage = result.image
            }
        }
    }

    func saveStackedImage() {
        guard let stackedImage else { return }

        Task {
            try? await exportStackedImage.execute(image: stackedImage)
        }
    }

    private func observeSelectedItems() {
        $selectedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }

                Task {
                    self.selectedImages = await self.importPhotos.execute(from: items)
                    self.stackedImage = nil
                }
            }
            .store(in: &cancellables)
    }
}
