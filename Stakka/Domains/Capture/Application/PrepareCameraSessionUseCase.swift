import AVFoundation

@MainActor
struct PrepareCameraSessionUseCase {
    private let repository: CameraDeviceRepository

    init(repository: CameraDeviceRepository) {
        self.repository = repository
    }

    func execute() async throws -> AVCaptureSession {
        try await repository.prepareSession()
        return repository.captureSession
    }
}
