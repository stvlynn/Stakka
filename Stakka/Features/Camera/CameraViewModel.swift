import SwiftUI
import AVFoundation

@MainActor
class CameraViewModel: ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var showSettings = false
    @Published var isCapturing = false
    @Published var capturedImages: [UIImage] = []
    @Published var exposureTime: Double = 1.0
    @Published var numberOfShots: Int = 10
    @Published var intervalBetweenShots: Double = 0.5
    @Published var captureProgress: Double = 0.0

    // Picker states
    @Published var showExposurePicker = false
    @Published var showShotsPicker = false
    @Published var showAperturePicker = false
    @Published var showShutterPicker = false
    @Published var showZoomPicker = false
    @Published var showModePicker = false

    // Advanced settings
    @Published var aperture: String = "f/1.8"
    @Published var shutterSpeed: String = "1/60"
    @Published var zoomLevel: String = "1×"
    @Published var shootingMode: String = "A"

    private var photoOutput = AVCapturePhotoOutput()
    private var currentShotCount = 0

    func setupCamera() {
        Task {
            await requestCameraPermission()
            await configureSession()
        }
    }

    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
    }

    private func configureSession() async {
        captureSession.beginConfiguration()

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    func startStackingCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        currentShotCount = 0
        capturedImages.removeAll()
        captureProgress = 0.0

        Task {
            await captureSequence()
        }
    }

    private func captureSequence() async {
        for i in 0..<numberOfShots {
            currentShotCount = i + 1
            await capturePhoto()
            captureProgress = Double(currentShotCount) / Double(numberOfShots)

            if i < numberOfShots - 1 {
                try? await Task.sleep(nanoseconds: UInt64(intervalBetweenShots * 1_000_000_000))
            }
        }
        isCapturing = false
    }

    private func capturePhoto() async {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate(viewModel: self))
    }

    func addCapturedImage(_ image: UIImage) {
        capturedImages.append(image)
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let viewModel: CameraViewModel

    init(viewModel: CameraViewModel) {
        self.viewModel = viewModel
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        Task { @MainActor in
            viewModel.addCapturedImage(image)
        }
    }
}
