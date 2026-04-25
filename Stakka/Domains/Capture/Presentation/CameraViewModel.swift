import AVFoundation
import SwiftUI

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var showSettings = false
    @Published var isCapturing = false
    @Published var capturedFrames: [CaptureFrame] = []
    @Published var captureProgress: Double = 0
    @Published var liveStackedImage: UIImage?
    @Published var liveStackedFrameCount = 0
    @Published var liveRejectedFrameCount = 0
    @Published var liveStackedExposure: Double = 0
    @Published var liveStackingPhase: LiveStackingPhase = .idle

    /// Identifies which capture parameter is currently driven by the
    /// inline horizontal wheel that lives above the controls drawer.
    /// Only one parameter can be edited at a time; tapping the same
    /// control toggles it off.
    @Published var activeInlineControl: CameraInlineControl?
    @Published var recentProjectTitle: String?

    @Published var exposureTime: Double = 15
    @Published var numberOfShots: Int = 24
    @Published var intervalBetweenShots: Double = 1
    @Published var aperture: String = "f/1.8"
    @Published var shutterSpeed: String = "15\""
    @Published var zoomLevel: String = "1×"
    @Published var shootingMode: String = ShootingMode.manual.rawValue
    @Published var astroMode: AstroCaptureMode = .milkyWay

    private let prepareCameraSession: PrepareCameraSessionUseCase
    private let startCaptureSequence: StartCaptureSequenceUseCase
    private let stopCaptureSequence: StopCaptureSequenceUseCase
    private let persistSession: PersistSessionUseCase
    private let replaceRecentProjectWithCapturedFrames: ReplaceRecentStackProjectWithCapturedFramesUseCase
    private let liveStackingProcessor: any LiveStackingProcessor
    private var captureTask: Task<Void, Never>?

    init(
        prepareCameraSession: PrepareCameraSessionUseCase,
        startCaptureSequence: StartCaptureSequenceUseCase,
        stopCaptureSequence: StopCaptureSequenceUseCase,
        persistSession: PersistSessionUseCase,
        replaceRecentProjectWithCapturedFrames: ReplaceRecentStackProjectWithCapturedFramesUseCase,
        liveStackingProcessor: any LiveStackingProcessor
    ) {
        self.prepareCameraSession = prepareCameraSession
        self.startCaptureSequence = startCaptureSequence
        self.stopCaptureSequence = stopCaptureSequence
        self.persistSession = persistSession
        self.replaceRecentProjectWithCapturedFrames = replaceRecentProjectWithCapturedFrames
        self.liveStackingProcessor = liveStackingProcessor
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
        recentProjectTitle = nil
        resetLiveStackingState()

        let settings = currentSettings
        let titleTime = Date()
        let (liveFrameStream, liveFrameContinuation) = makeLiveFrameStream()

        captureTask = Task { [weak self] in
            guard let self else { return }
            var liveProcessingTask: Task<Void, Never>?

            do {
                await liveStackingProcessor.reset(
                    configuration: liveStackingConfiguration(settings: settings, titleTime: titleTime)
                )
                liveProcessingTask = processLiveFrames(from: liveFrameStream)

                let frames = try await startCaptureSequence.execute(
                    settings: settings,
                    onFrameCaptured: { frame, index in
                        liveFrameContinuation.yield(LiveFrameEvent(frame: frame, index: index))
                    },
                    onProgress: { [weak self] progress in
                        self?.captureProgress = progress.fractionCompleted
                    }
                )
                liveFrameContinuation.finish()
                await liveProcessingTask?.value

                capturedFrames = frames
                if let liveProject = await liveStackingProcessor.currentProject(),
                   liveProject.frames.isEmpty == false {
                    recentProjectTitle = try? await replaceRecentProjectWithCapturedFrames.execute(project: liveProject).title
                } else {
                    recentProjectTitle = try? await replaceRecentProjectWithCapturedFrames.execute(frames: frames).title
                }
                isCapturing = false

                await persistSession.execute(
                    CaptureSession(
                        exposureTime: settings.exposureTime,
                        numberOfShots: settings.numberOfShots,
                        imageIdentifiers: frames.map(\.id.uuidString)
                    )
                )
            } catch {
                liveFrameContinuation.finish()
                liveProcessingTask?.cancel()
                isCapturing = false
                liveStackingPhase = .failed
            }
        }
    }

    func stopStackingCapture() {
        captureTask?.cancel()
        captureTask = nil
        stopCaptureSequence.execute()
        isCapturing = false
    }

    /// Toggles the inline wheel for the given control. Tapping the same
    /// control twice collapses the wheel; tapping a different control
    /// switches focus without an extra dismiss step.
    func toggleInlineControl(_ control: CameraInlineControl) {
        activeInlineControl = (activeInlineControl == control) ? nil : control
    }

    func dismissInlineControl() {
        activeInlineControl = nil
    }

    func updateExposure(by delta: Double) {
        updateExposureTime(max(0.1, min(30, (exposureTime + delta).rounded(toPlaces: 1))))
    }

    func updateInterval(by delta: Double) {
        intervalBetweenShots = max(0, min(10, (intervalBetweenShots + delta).rounded(toPlaces: 1)))
    }

    func updateShotCount(by delta: Int) {
        numberOfShots = max(2, min(100, numberOfShots + delta))
    }

    func updateExposureTime(_ value: Double) {
        exposureTime = value
        shutterSpeed = shutterDisplayText(for: value)
    }

    func updateShutterSpeed(_ value: String) {
        shutterSpeed = value
        if let duration = value.exposureDuration {
            exposureTime = duration
        }
    }

    func applyAstroMode(_ mode: AstroCaptureMode) {
        astroMode = mode

        switch mode {
        case .milkyWay:
            exposureTime = 15
            numberOfShots = 24
            intervalBetweenShots = 1
            aperture = "f/1.8"
            shutterSpeed = "15\""
            zoomLevel = "1×"
            shootingMode = ShootingMode.manual.rawValue
        case .starTrails:
            exposureTime = 30
            numberOfShots = 80
            intervalBetweenShots = 0.5
            aperture = "f/2.8"
            shutterSpeed = "30\""
            zoomLevel = "1×"
            shootingMode = ShootingMode.manual.rawValue
        case .moon:
            exposureTime = 1.0 / 125.0
            numberOfShots = 12
            intervalBetweenShots = 0.2
            aperture = "f/5.6"
            shutterSpeed = "1/125"
            zoomLevel = "3×"
            shootingMode = ShootingMode.shutterPriority.rawValue
        case .meteor:
            exposureTime = 20
            numberOfShots = 60
            intervalBetweenShots = 0.3
            aperture = "f/1.8"
            shutterSpeed = "20\""
            zoomLevel = "1×"
            shootingMode = ShootingMode.manual.rawValue
        }
    }

    private var currentSettings: CaptureSettings {
        CaptureSettings(
            astroMode: astroMode,
            exposureTime: exposureTime,
            numberOfShots: numberOfShots,
            intervalBetweenShots: intervalBetweenShots,
            aperture: aperture,
            shutterSpeed: shutterSpeed,
            zoomLevel: zoomLevel,
            shootingMode: ShootingMode(rawValue: shootingMode) ?? .aperturePriority
        )
    }

    private func makeLiveFrameStream() -> (
        stream: AsyncStream<LiveFrameEvent>,
        continuation: AsyncStream<LiveFrameEvent>.Continuation
    ) {
        var continuation: AsyncStream<LiveFrameEvent>.Continuation?
        let stream = AsyncStream<LiveFrameEvent> { streamContinuation in
            continuation = streamContinuation
        }

        guard let continuation else {
            preconditionFailure("AsyncStream continuation should be available after initialization")
        }

        return (stream, continuation)
    }

    private func processLiveFrames(from stream: AsyncStream<LiveFrameEvent>) -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }

            for await event in stream {
                guard Task.isCancelled == false else { break }

                let frame = event.frame
                let snapshot = await liveStackingProcessor.addFrame(
                    image: frame.image,
                    name: L10n.Project.captureFrameName(index: event.index),
                    source: .capture(identifier: frame.id.uuidString),
                    capturedAt: frame.capturedAt,
                    exposureDuration: frame.exposureDuration
                )
                applyLiveStackingSnapshot(snapshot)
            }
        }
    }

    private func resetLiveStackingState() {
        liveStackedImage = nil
        liveStackedFrameCount = 0
        liveRejectedFrameCount = 0
        liveStackedExposure = 0
        liveStackingPhase = .waitingForFrames
    }

    private func applyLiveStackingSnapshot(_ snapshot: LiveStackingSnapshot) {
        liveStackedImage = snapshot.previewImage
        liveStackedFrameCount = snapshot.acceptedFrameCount
        liveRejectedFrameCount = snapshot.rejectedFrameCount
        liveStackedExposure = snapshot.totalExposure
        liveStackingPhase = snapshot.phase
    }

    private func liveStackingConfiguration(
        settings: CaptureSettings,
        titleTime: Date
    ) -> LiveStackingConfiguration {
        LiveStackingConfiguration(
            strategy: settings.astroMode.liveStackingStrategy,
            title: L10n.Project.captureTitle(at: titleTime),
            exposureTime: settings.effectiveExposureDuration
        )
    }

    private func shutterDisplayText(for exposureDuration: Double) -> String {
        if exposureDuration < 1 {
            let denominator = max(1, Int((1 / exposureDuration).rounded()))
            return "1/\(denominator)"
        }

        return "\(Int(exposureDuration.rounded()))\""
    }
}

private struct LiveFrameEvent {
    let frame: CaptureFrame
    let index: Int
}

/// A capture parameter that can be driven by the inline horizontal wheel
/// that sits above the controls drawer. Exposure and shot count surface
/// in the collapsed drawer; aperture/shutter/zoom/mode are wired to
/// the same wheel from inside the expanded drawer for a consistent
/// editing model.
enum CameraInlineControl: Hashable {
    case exposure
    case shots
    case aperture
    case shutter
    case zoom
    case mode
}

private extension AstroCaptureMode {
    var liveStackingStrategy: LiveStackingStrategy {
        switch self {
        case .milkyWay:
            return .deepSky
        case .starTrails:
            return .starTrails
        case .moon:
            return .lunar
        case .meteor:
            return .meteor
        }
    }
}
