@MainActor
struct StopCaptureSequenceUseCase {
    private let repository: CameraDeviceRepository

    init(repository: CameraDeviceRepository) {
        self.repository = repository
    }

    func execute() {
        // Preview should remain active when users cancel a capture batch.
    }
}
