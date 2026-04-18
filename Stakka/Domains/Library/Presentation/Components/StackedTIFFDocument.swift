import SwiftUI
import UniformTypeIdentifiers

struct StackedTIFFDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.tiff]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw AppError.operationFailed("无法读取 TIFF 文档")
        }

        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
