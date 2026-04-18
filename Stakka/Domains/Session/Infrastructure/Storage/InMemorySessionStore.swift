import Foundation

actor InMemorySessionStore: SessionRepository {
    private var sessions: [CaptureSession] = []

    func save(_ session: CaptureSession) async {
        sessions.append(session)
    }

    func loadAll() async -> [CaptureSession] {
        sessions
    }
}
