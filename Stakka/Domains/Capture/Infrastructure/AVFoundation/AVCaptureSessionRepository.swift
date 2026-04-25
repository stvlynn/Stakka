@preconcurrency import AVFoundation
import UIKit

@MainActor
final class AVCaptureSessionRepository: NSObject, CameraDeviceRepository {
    let captureSession = AVCaptureSession()

    private let permissionService: CameraPermissionService
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.stakka.camera.session")
    private var activeDelegate: PhotoCaptureDelegate?

    init(permissionService: CameraPermissionService) {
        self.permissionService = permissionService
    }

    func prepareSession() async throws {
        try await permissionService.requestAccess()

        if captureSession.isRunning {
            return
        }

        try await configureSessionIfNeeded()
        sessionQueue.async { [captureSession] in
            captureSession.startRunning()
        }
    }

    func stopSession() {
        guard captureSession.isRunning else { return }

        sessionQueue.async { [captureSession] in
            captureSession.stopRunning()
        }
    }

    func capturePhoto(settings: CaptureSettings) async throws -> CaptureFrame {
        let exposureDuration = try await apply(settings)
        let image = try await captureUIImage()

        return CaptureFrame(
            image: image,
            capturedAt: Date(),
            exposureDuration: exposureDuration
        )
    }

    private func captureUIImage() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate { [weak self] result in
                self?.activeDelegate = nil
                continuation.resume(with: result)
            }

            activeDelegate = delegate
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }

    private func apply(_ settings: CaptureSettings) async throws -> Double {
        guard let device = activeVideoDevice else {
            return settings.effectiveExposureDuration
        }

        let appliedDuration = clampedExposureDuration(
            requestedSeconds: settings.effectiveExposureDuration,
            for: device
        )
        let appliedISO = min(max(device.iso, device.activeFormat.minISO), device.activeFormat.maxISO)

        try device.lockForConfiguration()
        configureZoom(settings.effectiveZoomFactor, on: device)

        guard device.isExposureModeSupported(.custom) else {
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
            return settings.effectiveExposureDuration
        }

        await withCheckedContinuation { continuation in
            device.setExposureModeCustom(duration: appliedDuration, iso: appliedISO) { _ in
                continuation.resume()
            }
        }
        device.unlockForConfiguration()

        return CMTimeGetSeconds(appliedDuration)
    }

    private var activeVideoDevice: AVCaptureDevice? {
        captureSession.inputs
            .compactMap { ($0 as? AVCaptureDeviceInput)?.device }
            .first { $0.hasMediaType(.video) }
    }

    private func configureZoom(_ zoomFactor: CGFloat, on device: AVCaptureDevice) {
        let maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 10)
        device.videoZoomFactor = min(max(zoomFactor, 1), maxZoomFactor)
    }

    private func clampedExposureDuration(
        requestedSeconds: Double,
        for device: AVCaptureDevice
    ) -> CMTime {
        let requested = CMTime(
            seconds: max(requestedSeconds, 1.0 / 8_000.0),
            preferredTimescale: 1_000_000_000
        )
        let minimum = device.activeFormat.minExposureDuration
        let maximum = device.activeFormat.maxExposureDuration

        if CMTimeCompare(requested, minimum) < 0 { return minimum }
        if CMTimeCompare(requested, maximum) > 0 { return maximum }
        return requested
    }

    private func configureSessionIfNeeded() async throws {
        guard captureSession.inputs.isEmpty else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        defer { captureSession.commitConfiguration() }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw AppError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<UIImage, Error>) -> Void

    init(completion: @escaping (Result<UIImage, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(.failure(AppError.operationFailed(L10n.Error.photoProcessingFailed)))
            return
        }

        completion(.success(image))
    }
}
