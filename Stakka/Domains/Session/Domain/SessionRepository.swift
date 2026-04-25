import Foundation

protocol SessionRepository: AnyObject, Sendable {
    func save(_ session: CaptureSession) async
    func loadAll() async -> [CaptureSession]
}
