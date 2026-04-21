import PhotosUI
import SwiftUI

/// Loads and caches small thumbnail UIImages for `PhotosPickerItem`s shown
/// inside the project-creation wizard.
///
/// `PhotosPickerItem` only exposes async `loadTransferable` — calling it on
/// every redraw would re-decode each image many times during a typical
/// SwiftUI view update. This `@MainActor` cache keeps decoded thumbnails
/// keyed by `itemIdentifier` (or, as a fallback, the underlying `objectID`
/// description) so the strip stays smooth even with dozens of frames.
@MainActor
final class WizardThumbnailLoader: ObservableObject {
    @Published private(set) var images: [String: UIImage] = [:]
    private var inFlight: Set<String> = []

    /// Maximum decoded size in pixels. 256pt @3x ≈ 768px is plenty for the
    /// 64pt thumbnail strip and keeps memory bounded.
    private let maxPixelSize: CGFloat = 256

    func image(for item: PhotosPickerItem) -> UIImage? {
        images[Self.cacheKey(for: item)]
    }

    func load(_ item: PhotosPickerItem) {
        let key = Self.cacheKey(for: item)
        guard images[key] == nil, !inFlight.contains(key) else { return }
        inFlight.insert(key)

        Task { [weak self, maxPixelSize] in
            let thumb = await Self.decodeThumbnail(item: item, maxPixelSize: maxPixelSize)
            await MainActor.run {
                guard let self else { return }
                self.inFlight.remove(key)
                if let thumb {
                    self.images[key] = thumb
                }
            }
        }
    }

    /// Drops cached entries that no longer correspond to a live item. Called
    /// by the strip when its `items` array changes.
    func prune(keeping current: [PhotosPickerItem]) {
        let liveKeys = Set(current.map(Self.cacheKey(for:)))
        images = images.filter { liveKeys.contains($0.key) }
    }

    static func cacheKey(for item: PhotosPickerItem) -> String {
        item.itemIdentifier ?? String(describing: item)
    }

    private static func decodeThumbnail(item: PhotosPickerItem, maxPixelSize: CGFloat) async -> UIImage? {
        guard let raw = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            // ImageIO downsampling — avoids decoding the full-resolution
            // photo just to render a 64pt tile.
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            guard let source = CGImageSourceCreateWithData(raw as CFData, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            else {
                return UIImage(data: raw)
            }
            return UIImage(cgImage: cg)
        }.value
    }
}
