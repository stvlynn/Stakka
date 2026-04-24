import Foundation

@MainActor
struct StartCaptureSequenceUseCase {
    private let repository: CameraDeviceRepository

    init(repository: CameraDeviceRepository) {
        self.repository = repository
    }

    func execute(
        settings: CaptureSettings,
        onFrameCaptured: @escaping (CaptureFrame, Int) -> Void = { _, _ in },
        onProgress: @escaping (CaptureProgress) async -> Void
    ) async throws -> [CaptureFrame] {
        var frames: [CaptureFrame] = []

        for index in 0..<settings.numberOfShots {
            try Task.checkCancellation()

            let frame = try await repository.capturePhoto(settings: settings)
            frames.append(frame)

            onFrameCaptured(frame, index + 1)

            await onProgress(CaptureProgress(completedShots: index + 1, totalShots: settings.numberOfShots))

            if index < settings.numberOfShots - 1 {
                try Task.checkCancellation()
                try await Task.sleep(for: .seconds(settings.intervalBetweenShots))
            }
        }

        return frames
    }
}
