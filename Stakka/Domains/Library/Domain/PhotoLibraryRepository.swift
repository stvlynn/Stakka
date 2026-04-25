import PhotosUI
import SwiftUI
import UIKit

protocol PhotoLibraryRepository: Sendable {
    func loadFrames(from items: [PhotosPickerItem], kind: StackFrameKind) async -> [StackFrame]
    func loadFrames(from fileURLs: [URL], kind: StackFrameKind) async -> [StackFrame]
    func save(image: UIImage) async throws
}
