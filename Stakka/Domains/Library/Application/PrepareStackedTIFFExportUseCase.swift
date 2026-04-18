import Foundation

struct StackedTIFFExport: Sendable {
    let filename: String
    let data: Data
}

struct PrepareStackedTIFFExportUseCase {
    func execute(result: StackingResult) -> StackedTIFFExport {
        let timestamp = ISO8601DateFormatter.fileSafe.string(from: Date())
        return StackedTIFFExport(
            filename: "Stakka-\(result.mode.rawValue)-\(timestamp)",
            data: result.tiffData
        )
    }
}
