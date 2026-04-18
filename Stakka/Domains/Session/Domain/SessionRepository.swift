import Foundation

protocol SessionRepository: AnyObject {
    func save(_ session: CaptureSession) async
    func loadAll() async -> [CaptureSession]
}
