import AVFoundation
import SwiftUI

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var showSettings = false
    @Published var isCapturing = false
    @Published var capturedFrames: [CaptureFrame] = []
    @Published var captureProgress: Double = 0

    @Published var showExposurePicker = false
    @Published var showShotsPicker = false
    @Published var showAperturePicker = false
    @Published var showShutterPicker = false
    @Published var showZoomPicker = false
    @Published var showModePicker = false
    @Published var recentProjectTitle: String?

    @Published var exposureTime: Double = 1.0
    @Published var numberOfShots: Int = 10
    @Published var intervalBetweenShots: Double = 0.5
    @Published var aperture: String = "f/1.8"
    @Published var shutterSpeed: String = "1/60"
    @Published var zoomLevel: String = "1×"
    @Published var shootingMode: String = ShootingMode.aperturePriority.rawValue

    private let prepareCameraSession: PrepareCameraSessionUseCase
    private let startCaptureSequence: StartCaptureSequenceUseCase
    private let stopCaptureSequence: StopCaptureSequenceUseCase
    private let persistSession: PersistSessionUseCase
    private let replaceRecentProjectWithCapturedFrames: ReplaceRecentStackProjectWithCapturedFramesUseCase
    private var captureTask: Task<Void, Never>?

    init(
        prepareCameraSession: PrepareCameraSessionUseCase,
        startCaptureSequence: StartCaptureSequenceUseCase,
        stopCaptureSequence: StopCaptureSequenceUseCase,
        persistSession: PersistSessionUseCase,
        replaceRecentProjectWithCapturedFrames: ReplaceRecentStackProjectWithCapturedFramesUseCase
    ) {
        self.prepareCameraSession = prepareCameraSession
        self.startCaptureSequence = startCaptureSequence
        self.stopCaptureSequence = stopCaptureSequence
        self.persistSession = persistSession
        self.replaceRecentProjectWithCapturedFrames = replaceRecentProjectWithCapturedFrames
    }

    func setupCamera() {
        Task {
            captureSession = (try? await prepareCameraSession.execute()) ?? AVCaptureSession()
        }
    }

    func startStackingCapture() {
        guard !isCapturing else { return }

        isCapturing = true
        capturedFrames.removeAll()
        captureProgress = 0

        let settings = currentSettings

        captureTask = Task { [weak self] in
            guard let self else { return }

            do {
                let frames = try await startCaptureSequence.execute(settings: settings) { [weak self] progress in
                    self?.captureProgress = progress.fractionCompleted
                }

                capturedFrames = frames
                recentProjectTitle = try? await replaceRecentProjectWithCapturedFrames.execute(frames: frames).title
                isCapturing = false

                await persistSession.execute(
                    CaptureSession(
                        exposureTime: settings.exposureTime,
                        numberOfShots: settings.numberOfShots,
                        imageIdentifiers: frames.map(\.id.uuidString)
                    )
                )
            } catch {
                isCapturing = false
            }
        }
    }

    func stopStackingCapture() {
        captureTask?.cancel()
        captureTask = nil
        stopCaptureSequence.execute()
        isCapturing = false
    }

    func updateExposure(by delta: Double) {
        exposureTime = max(0.1, min(30, (exposureTime + delta).rounded(toPlaces: 1)))
    }

    func updateInterval(by delta: Double) {
        intervalBetweenShots = max(0, min(10, (intervalBetweenShots + delta).rounded(toPlaces: 1)))
    }

    func updateShotCount(by delta: Int) {
        numberOfShots = max(2, min(100, numberOfShots + delta))
    }

    private var currentSettings: CaptureSettings {
        CaptureSettings(
            exposureTime: exposureTime,
            numberOfShots: numberOfShots,
            intervalBetweenShots: intervalBetweenShots,
            aperture: aperture,
            shutterSpeed: shutterSpeed,
            zoomLevel: zoomLevel,
            shootingMode: ShootingMode(rawValue: shootingMode) ?? .aperturePriority
        )
    }
}
