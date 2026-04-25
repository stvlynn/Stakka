import AVFoundation
import UIKit

enum ShootingMode: String, CaseIterable, Sendable {
    case aperturePriority = "A"
    case manual = "M"
    case program = "P"
    case shutterPriority = "S"
}

enum AstroCaptureMode: String, CaseIterable, Identifiable, Sendable {
    case milkyWay
    case starTrails
    case moon
    case meteor

    var id: String { rawValue }
}

struct CaptureSettings: Sendable {
    var astroMode: AstroCaptureMode = .milkyWay
    var exposureTime: Double = 1.0
    var numberOfShots: Int = 10
    var intervalBetweenShots: Double = 0.5
    var aperture: String = "f/1.8"
    var shutterSpeed: String = "1/60"
    var zoomLevel: String = "1×"
    var shootingMode: ShootingMode = .aperturePriority
}

struct CaptureFrame: Identifiable, Sendable {
    let id: UUID
    let image: UIImage
    let capturedAt: Date
    let exposureDuration: Double

    init(
        id: UUID = UUID(),
        image: UIImage,
        capturedAt: Date,
        exposureDuration: Double = 1.0
    ) {
        self.id = id
        self.image = image
        self.capturedAt = capturedAt
        self.exposureDuration = exposureDuration
    }
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
    func capturePhoto(settings: CaptureSettings) async throws -> CaptureFrame
}

extension CaptureSettings {
    var effectiveExposureDuration: Double {
        shutterSpeed.exposureDuration ?? exposureTime
    }

    var effectiveZoomFactor: CGFloat {
        zoomLevel.zoomFactor ?? 1
    }
}

extension String {
    var exposureDuration: Double? {
        if hasSuffix("\"") {
            return Double(dropLast())
        }

        let parts = split(separator: "/")
        if parts.count == 2,
           let numerator = Double(parts[0]),
           let denominator = Double(parts[1]),
           denominator > 0 {
            return numerator / denominator
        }

        return Double(self)
    }

    var zoomFactor: CGFloat? {
        let normalized = replacingOccurrences(of: "×", with: "")
        guard let value = Double(normalized) else { return nil }
        return CGFloat(value)
    }
}
