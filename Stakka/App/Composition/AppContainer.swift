import Foundation

@MainActor
final class AppContainer {
    private let darkSkyRepository: DarkSkyRepository
    private let locationService: CoreLocationService
    private let cameraRepository: AVCaptureSessionRepository
    private let stackingProcessor: any StackingProcessor
    private let stackProjectRepository: any StackProjectRepository
    private let photoLibraryRepository: PhotoLibraryRepository
    private let sessionRepository: SessionRepository

    init() {
        darkSkyRepository = VIIRSDarkSkyRepository()
        locationService = CoreLocationService()
        cameraRepository = AVCaptureSessionRepository(permissionService: CameraPermissionService())
        stackingProcessor = ImageStacker()
        stackProjectRepository = LocalStackProjectRepository()
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
            persistSession: PersistSessionUseCase(repository: sessionRepository),
            replaceRecentProjectWithCapturedFrames: ReplaceRecentStackProjectWithCapturedFramesUseCase(repository: stackProjectRepository)
        )
    }

    func makeLibraryViewModel() -> LibraryStackingViewModel {
        LibraryStackingViewModel(
            importPhotos: ImportPhotosUseCase(repository: photoLibraryRepository),
            loadRecentProject: LoadRecentStackProjectUseCase(repository: stackProjectRepository),
            loadProject: LoadStackProjectUseCase(repository: stackProjectRepository),
            loadProjectSummaries: LoadStackProjectSummariesUseCase(repository: stackProjectRepository),
            persistProject: PersistStackProjectUseCase(repository: stackProjectRepository),
            clearRecentProject: ClearRecentStackProjectUseCase(repository: stackProjectRepository),
            duplicateProject: DuplicateStackProjectUseCase(repository: stackProjectRepository),
            deleteProject: DeleteStackProjectUseCase(repository: stackProjectRepository),
            markRecentProject: MarkRecentStackProjectUseCase(repository: stackProjectRepository),
            analyzeProject: AnalyzeStackProjectUseCase(processor: stackingProcessor),
            registerProject: RegisterStackProjectUseCase(processor: stackingProcessor),
            runStacking: RunStackingUseCase(processor: stackingProcessor),
            exportStackedImage: ExportStackedImageUseCase(repository: photoLibraryRepository),
            prepareTIFFExport: PrepareStackedTIFFExportUseCase()
        )
    }
}
