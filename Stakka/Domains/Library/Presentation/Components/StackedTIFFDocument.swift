import SwiftUI
import UniformTypeIdentifiers

struct StackedTIFFDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.tiff]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw AppError.operationFailed(L10n.Error.tiffReadFailed)
        }

        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
