import AVFoundation
import XCTest
@testable import Stakka

@MainActor
final class StartCaptureSequenceUseCaseTests: XCTestCase {
    func testExecutePassesCaptureSettingsToCameraRepository() async throws {
        let repository = FakeCameraDeviceRepository()
        let useCase = StartCaptureSequenceUseCase(repository: repository)
        let settings = CaptureSettings(
            astroMode: .moon,
            exposureTime: 1.0 / 125.0,
            numberOfShots: 2,
            intervalBetweenShots: 0,
            shutterSpeed: "1/125",
            zoomLevel: "3×",
            shootingMode: .shutterPriority
        )

        let frames = try await useCase.execute(settings: settings, onFrameCaptured: { _, _ in }) { _ in }

        XCTAssertEqual(repository.receivedSettings.map(\.astroMode), [.moon, .moon])
        XCTAssertEqual(repository.receivedSettings.map(\.effectiveZoomFactor), [3, 3])
        XCTAssertEqual(frames.map(\.exposureDuration), [1.0 / 125.0, 1.0 / 125.0])
    }

    func testExecuteEmitsFramesWithoutAwaitingLiveProcessingWork() async throws {
        let repository = FakeCameraDeviceRepository()
        let useCase = StartCaptureSequenceUseCase(repository: repository)
        let settings = CaptureSettings(numberOfShots: 2, intervalBetweenShots: 0)
        var emittedFrameIndexes: [Int] = []

        _ = try await useCase.execute(
            settings: settings,
            onFrameCaptured: { _, index in
                emittedFrameIndexes.append(index)
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                }
            },
            onProgress: { _ in }
        )

        XCTAssertEqual(emittedFrameIndexes, [1, 2])
        XCTAssertEqual(repository.receivedSettings.count, 2)
    }
}

@MainActor
private final class FakeCameraDeviceRepository: CameraDeviceRepository {
    let captureSession = AVCaptureSession()
    var receivedSettings: [CaptureSettings] = []

    func prepareSession() async throws {}

    func stopSession() {}

    func capturePhoto(settings: CaptureSettings) async throws -> CaptureFrame {
        receivedSettings.append(settings)
        return CaptureFrame(
            image: PatternImageFactory.uniformGray(width: 8, height: 8, value: 120),
            capturedAt: Date(),
            exposureDuration: settings.effectiveExposureDuration
        )
    }
}
