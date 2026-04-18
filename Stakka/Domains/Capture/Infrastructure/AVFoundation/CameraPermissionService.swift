import AVFoundation

struct CameraPermissionService {
    func requestAccess() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw AppError.permissionDenied
            }
        default:
            throw AppError.permissionDenied
        }
    }
}
