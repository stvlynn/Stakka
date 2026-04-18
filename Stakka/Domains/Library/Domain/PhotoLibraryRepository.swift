import PhotosUI
import SwiftUI
import UIKit

protocol PhotoLibraryRepository {
    func loadImages(from items: [PhotosPickerItem]) async -> [ImportedImage]
    func save(image: UIImage) async throws
}
