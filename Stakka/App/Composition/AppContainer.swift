import Foundation

@MainActor
final class AppContainer {
    private let darkSkyRepository: DarkSkyRepository
    private let locationService: CoreLocationService
    private let cameraRepository: AVCaptureSessionRepository
    private let stackingProcessor: any StackingProcessor
    private let photoLibraryRepository: PhotoLibraryRepository
    private let sessionRepository: SessionRepository

    init() {
        darkSkyRepository = MockDarkSkyRepository()
        locationService = CoreLocationService()
        cameraRepository = AVCaptureSessionRepository(permissionService: CameraPermissionService())
        stackingProcessor = ImageStacker()
        photoLibraryRepository = SystemPhotoLibraryRepository()
        sessionRepository = InMemorySessionStore()
    }

    func makeDarkSkyViewModel() -> DarkSkyViewModel {
        DarkSkyViewModel(
            fetchPollutionAtLocation: FetchPollutionAtLocationUseCase(repository: darkSkyRepository),
            centerOnUserLocation: CenterOnUserLocationUseCase(locationService: locationService)
        )
    }

    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(
            prepareCameraSession: PrepareCameraSessionUseCase(repository: cameraRepository),
            startCaptureSequence: StartCaptureSequenceUseCase(repository: cameraRepository),
            stopCaptureSequence: StopCaptureSequenceUseCase(repository: cameraRepository),
            persistSession: PersistSessionUseCase(repository: sessionRepository)
        )
    }

    func makeLibraryViewModel() -> LibraryStackingViewModel {
        LibraryStackingViewModel(
            importPhotos: ImportPhotosUseCase(repository: photoLibraryRepository),
            runStacking: RunStackingUseCase(processor: stackingProcessor),
            exportStackedImage: ExportStackedImageUseCase(repository: photoLibraryRepository)
        )
    }
}
