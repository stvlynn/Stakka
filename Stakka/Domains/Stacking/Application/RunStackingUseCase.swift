import UIKit

struct RunStackingUseCase {
    private let processor: any StackingProcessor

    init(processor: any StackingProcessor) {
        self.processor = processor
    }

    func execute(images: [UIImage], mode: StackingMode = .mean) async throws -> StackingResult {
        try await processor.process(StackingRequest(images: images, mode: mode))
    }
}
