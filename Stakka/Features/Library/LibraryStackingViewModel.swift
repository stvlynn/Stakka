import SwiftUI
import PhotosUI
import Combine

@MainActor
class LibraryStackingViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published var selectedImages: [UIImage] = []
    @Published var isStacking = false
    @Published var stackedImage: UIImage?

    private var cancellables = Set<AnyCancellable>()

    init() {
        observeSelectedItems()
    }

    private func observeSelectedItems() {
        $selectedItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                Task {
                    await self?.loadImages(from: items)
                }
            }
            .store(in: &cancellables)
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        selectedImages.removeAll()
        stackedImage = nil

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImages.append(image)
            }
        }
    }

    func stackImages() {
        guard !selectedImages.isEmpty else { return }
        isStacking = true

        Task {
            let stacker = ImageStacker()
            if let result = await stacker.stackImages(selectedImages) {
                stackedImage = result
            }
            isStacking = false
        }
    }

    func saveStackedImage() {
        guard let image = stackedImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
