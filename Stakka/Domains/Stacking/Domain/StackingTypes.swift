import UIKit

enum StackingMode: String, Sendable {
    case mean
}

struct StackingRequest {
    let images: [UIImage]
    let mode: StackingMode
}

struct StackingResult {
    let image: UIImage
    let frameCount: Int
    let mode: StackingMode
}

enum StackingError: Error, LocalizedError {
    case emptyInput
    case incompatibleDimensions
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "没有可堆栈的图像"
        case .incompatibleDimensions:
            return "图像尺寸不一致"
        case .processingFailed:
            return "堆栈处理失败"
        }
    }
}

protocol StackingProcessor {
    func process(_ request: StackingRequest) async throws -> StackingResult
}
