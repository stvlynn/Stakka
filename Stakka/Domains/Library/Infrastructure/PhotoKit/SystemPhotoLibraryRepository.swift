import Photos
import PhotosUI
import SwiftUI
import UIKit

struct SystemPhotoLibraryRepository: PhotoLibraryRepository {
    func loadImages(from items: [PhotosPickerItem]) async -> [ImportedImage] {
        var importedImages: [ImportedImage] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                importedImages.append(ImportedImage(image: image))
            }
        }

        return importedImages
    }

    func save(image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: AppError.operationFailed("保存失败"))
                }
            }
        }
    }
}
