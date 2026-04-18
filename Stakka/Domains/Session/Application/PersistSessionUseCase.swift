import Foundation

struct PersistSessionUseCase {
    private let repository: SessionRepository

    init(repository: SessionRepository) {
        self.repository = repository
    }

    func execute(_ session: CaptureSession) async {
        await repository.save(session)
    }
}
