import Photos
import PhotosUI
import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

struct SystemPhotoLibraryRepository: PhotoLibraryRepository {
    func loadFrames(from items: [PhotosPickerItem], kind: StackFrameKind) async -> [StackFrame] {
        var importedFrames: [StackFrame] = []

        for (index, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let preparedImage = prepareImage(image)
                let name = "\(kind.shortLabel)-\(index + 1)"
                importedFrames.append(
                    StackFrame(
                        kind: kind,
                        name: name,
                        source: .photoLibrary(assetIdentifier: item.itemIdentifier),
                        image: preparedImage
                    )
                )
            }
        }

        return importedFrames
    }

    func loadFrames(from fileURLs: [URL], kind: StackFrameKind) async -> [StackFrame] {
        var importedFrames: [StackFrame] = []

        for (index, url) in fileURLs.enumerated() {
            guard let image = loadImage(at: url) else { continue }

            importedFrames.append(
                StackFrame(
                    kind: kind,
                    name: url.deletingPathExtension().lastPathComponent.isEmpty ? "\(kind.shortLabel)-\(index + 1)" : url.deletingPathExtension().lastPathComponent,
                    source: .fileURL(url),
                    image: prepareImage(image)
                )
            )
        }

        return importedFrames
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

    private func prepareImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1_536
        let size = image.size
        let maxSide = max(size.width, size.height)

        guard maxSide > maxDimension else {
            return normalizedImage(image)
        }

        let scale = maxDimension / maxSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            normalizedImage(image).draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func loadImage(at url: URL) -> UIImage? {
        if let imageData = try? Data(contentsOf: url),
           let image = UIImage(data: imageData) {
            return image
        }

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
