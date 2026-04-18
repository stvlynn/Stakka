import AVFoundation
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

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = PhotoCaptureDelegate { [weak self] result in
                self?.activeDelegate = nil
                continuation.resume(with: result)
            }

            activeDelegate = delegate
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
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
            completion(.failure(AppError.operationFailed("照片处理失败")))
            return
        }

        completion(.success(image))
    }
}
