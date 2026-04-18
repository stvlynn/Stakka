import AVFoundation
import UIKit

enum ShootingMode: String, CaseIterable, Sendable {
    case aperturePriority = "A"
    case manual = "M"
    case program = "P"
    case shutterPriority = "S"
}

struct CaptureSettings: Sendable {
    var exposureTime: Double = 1.0
    var numberOfShots: Int = 10
    var intervalBetweenShots: Double = 0.5
    var aperture: String = "f/1.8"
    var shutterSpeed: String = "1/60"
    var zoomLevel: String = "1×"
    var shootingMode: ShootingMode = .aperturePriority
}

struct CaptureFrame: Identifiable {
    let id = UUID()
    let image: UIImage
    let capturedAt: Date
}

struct CaptureProgress: Sendable {
    let completedShots: Int
    let totalShots: Int

    var fractionCompleted: Double {
        ProgressValue(completed: completedShots, total: totalShots).fractionCompleted
    }
}

@MainActor
protocol CameraDeviceRepository: AnyObject {
    var captureSession: AVCaptureSession { get }
    func prepareSession() async throws
    func stopSession()
    func capturePhoto() async throws -> UIImage
}
