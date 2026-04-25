import Foundation

struct PersistSessionUseCase: Sendable {
    private let repository: any SessionRepository

    init(repository: any SessionRepository) {
        self.repository = repository
    }

    func execute(_ session: CaptureSession) async {
        await repository.save(session)
    }
}
