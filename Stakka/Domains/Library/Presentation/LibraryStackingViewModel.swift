import Combine
import PhotosUI
import SwiftUI

@MainActor
final class LibraryStackingViewModel: ObservableObject {
    enum ProcessingPhase {
        case idle
        case analyzing
        case registering
        case stacking
        case saving

        var title: String {
            switch self {
            case .idle:
                return "就绪"
            case .analyzing:
                return "分析"
            case .registering:
                return "配准"
            case .stacking:
                return "堆栈"
            case .saving:
                return "保存"
            }
        }

        var symbolName: String {
            switch self {
            case .idle:
                return "checkmark.circle"
            case .analyzing:
                return "viewfinder"
            case .registering:
                return "scope"
            case .stacking:
                return "square.stack.3d.up.fill"
            case .saving:
                return "square.and.arrow.down.fill"
            }
        }
    }

    @Published private(set) var project = StackingProject()
    @Published private(set) var projectSummaries: [StackProjectSummary] = []
    @Published private(set) var phase: ProcessingPhase = .idle
    @Published private(set) var result: StackingResult?
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingTIFFExport: StackedTIFFExport?
    @Published var isPresentingTIFFExporter = false

    private let importPhotos: ImportPhotosUseCase
    private let loadRecentProject: LoadRecentStackProjectUseCase
    private let loadProject: LoadStackProjectUseCase
    private let loadProjectSummaries: LoadStackProjectSummariesUseCase
    private let persistProject: PersistStackProjectUseCase
    private let clearRecentProject: ClearRecentStackProjectUseCase
    private let duplicateProjectUseCase: DuplicateStackProjectUseCase
    private let deleteProjectUseCase: DeleteStackProjectUseCase
    private let markRecentProjectUseCase: MarkRecentStackProjectUseCase
    private let analyzeProject: AnalyzeStackProjectUseCase
    private let registerProject: RegisterStackProjectUseCase
    private let runStacking: RunStackingUseCase
    private let exportStackedImage: ExportStackedImageUseCase
    private let prepareTIFFExport: PrepareStackedTIFFExportUseCase
    private var hasLoadedRecentProject = false
    private var persistTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        importPhotos: ImportPhotosUseCase,
        loadRecentProject: LoadRecentStackProjectUseCase,
        loadProject: LoadStackProjectUseCase,
        loadProjectSummaries: LoadStackProjectSummariesUseCase,
        persistProject: PersistStackProjectUseCase,
        clearRecentProject: ClearRecentStackProjectUseCase,
        duplicateProject: DuplicateStackProjectUseCase,
        deleteProject: DeleteStackProjectUseCase,
        markRecentProject: MarkRecentStackProjectUseCase,
        analyzeProject: AnalyzeStackProjectUseCase,
        registerProject: RegisterStackProjectUseCase,
        runStacking: RunStackingUseCase,
        exportStackedImage: ExportStackedImageUseCase,
        prepareTIFFExport: PrepareStackedTIFFExportUseCase
    ) {
        self.importPhotos = importPhotos
        self.loadRecentProject = loadRecentProject
        self.loadProject = loadProject
        self.loadProjectSummaries = loadProjectSummaries
        self.persistProject = persistProject
        self.clearRecentProject = clearRecentProject
        self.duplicateProjectUseCase = duplicateProject
        self.deleteProjectUseCase = deleteProject
        self.markRecentProjectUseCase = markRecentProject
        self.analyzeProject = analyzeProject
        self.registerProject = registerProject
        self.runStacking = runStacking
        self.exportStackedImage = exportStackedImage
        self.prepareTIFFExport = prepareTIFFExport
        observeRecentProjectChanges()
    }

    var isWorking: Bool {
        phase != .idle
    }

    var hasCometModeEnabled: Bool {
        project.cometMode != nil
    }

    var cometReviewFrameIDs: [UUID] {
        project.enabledLightFrames.map(\.id)
    }

    var firstCometReviewFrameID: UUID? {
        project.enabledFramesNeedingCometReview.first?.id ?? cometReviewFrameIDs.first
    }

    var cometReviewedCount: Int {
        project.cometAnnotations.values.filter { !$0.requiresReview }.count
    }

    func loadRecentProjectIfNeeded() async {
        guard !hasLoadedRecentProject else { return }
        hasLoadedRecentProject = true

        do {
            projectSummaries = try await loadProjectSummaries.execute()
            if let storedProject = try await loadRecentProject.execute() {
                project = storedProject
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setMode(_ mode: StackingMode) {
        guard project.mode != mode else { return }
        project.mode = mode
        invalidateComputedState()
    }

    func setCometMode(_ mode: CometStackingMode?) {
        guard project.cometMode != mode else { return }
        project.cometMode = mode
        result = nil
        errorMessage = nil

        if mode == nil {
            project.cometAnnotations = [:]
        }

        schedulePersistence()
    }

    func importFrames(from items: [PhotosPickerItem], kind: StackFrameKind) async {
        let frames = await importPhotos.execute(from: items, kind: kind)
        guard !frames.isEmpty else { return }

        project.frames.append(contentsOf: frames)
        invalidateComputedState()
    }

    func importFrames(from fileURLs: [URL], kind: StackFrameKind) async {
        let frames = await importPhotos.execute(from: fileURLs, kind: kind)
        guard !frames.isEmpty else { return }

        project.frames.append(contentsOf: frames)
        invalidateComputedState()
    }

    func createNewProject() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        project = StackingProject(title: "新工程 \(formatter.string(from: Date()))")
        result = nil
        errorMessage = nil
        pendingTIFFExport = nil
        schedulePersistence()
    }

    func openProject(id: UUID) {
        Task {
            do {
                if let loadedProject = try await loadProject.execute(id: id) {
                    project = loadedProject
                    result = nil
                    errorMessage = nil
                    try await markRecentProjectUseCase.execute(id: id)
                    projectSummaries = try await loadProjectSummaries.execute()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func duplicateProject(id: UUID) {
        Task {
            do {
                let duplicated = try await duplicateProjectUseCase.execute(id: id)
                project = duplicated
                projectSummaries = try await loadProjectSummaries.execute()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteProject(id: UUID) {
        Task {
            do {
                try await deleteProjectUseCase.execute(id: id)
                projectSummaries = try await loadProjectSummaries.execute()

                if project.id == id {
                    if let recentProject = try await loadRecentProject.execute() {
                        project = recentProject
                    } else {
                        project = StackingProject()
                    }
                    result = nil
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearGroup(_ kind: StackFrameKind) {
        project.frames.removeAll { $0.kind == kind }
        if let referenceFrameID = project.referenceFrameID,
           project.frame(id: referenceFrameID) == nil {
            project.referenceFrameID = nil
        }
        invalidateComputedState()
    }

    func removeFrame(_ frameID: UUID) {
        project.frames.removeAll { $0.id == frameID }
        if project.referenceFrameID == frameID {
            project.referenceFrameID = nil
        }
        invalidateComputedState()
    }

    func toggleFrame(_ frameID: UUID) {
        guard let index = project.frames.firstIndex(where: { $0.id == frameID }) else { return }
        project.frames[index].isEnabled.toggle()

        if !project.frames[index].isEnabled, project.referenceFrameID == frameID {
            project.referenceFrameID = nil
        }

        invalidateComputedState()
    }

    func setReferenceFrame(_ frameID: UUID) {
        guard let frame = project.frame(id: frameID), frame.kind == .light else { return }
        project.referenceFrameID = frameID

        if let index = project.frames.firstIndex(where: { $0.id == frameID }) {
            project.frames[index].isEnabled = true
        }

        result = nil
        errorMessage = nil
        schedulePersistence()
    }

    func analyze() {
        runOperation(phase: .analyzing) {
            self.project = try await self.analyzeProject.execute(project: self.project)
        }
    }

    func register() {
        runOperation(phase: .registering) {
            self.project = try await self.registerProject.execute(project: self.project)
        }
    }

    func stack() {
        runOperation(phase: .stacking) {
            let registeredProject = try await self.registerProject.execute(project: self.project)
            self.project = registeredProject
            self.result = try await self.runStacking.execute(project: registeredProject)
        }
    }

    func saveResult() {
        guard let image = result?.image else { return }

        runOperation(phase: .saving) {
            try await self.exportStackedImage.execute(image: image)
        }
    }

    func prepareResultTIFFExport() {
        guard let result else { return }
        pendingTIFFExport = prepareTIFFExport.execute(result: result)
        isPresentingTIFFExporter = true
    }

    func cometAnnotation(for frameID: UUID) -> CometAnnotation? {
        project.cometAnnotations[frameID]
    }

    func markCometPoint(_ point: PixelPoint, for frameID: UUID) {
        guard let frame = project.frame(id: frameID) else { return }

        let existing = project.cometAnnotations[frameID]
        project.cometAnnotations[frameID] = CometAnnotation(
            estimatedPoint: existing?.estimatedPoint,
            resolvedPoint: point,
            confidence: existing?.confidence ?? 1,
            isUserAdjusted: true,
            requiresReview: false,
            sourceFrameSize: existing?.sourceFrameSize ?? PixelSize(
                width: frame.image.size.width,
                height: frame.image.size.height
            )
        )

        result = nil
        errorMessage = nil
        schedulePersistence()
    }

    func restoreEstimatedCometPoint(for frameID: UUID) {
        guard let existing = project.cometAnnotations[frameID] else { return }
        project.cometAnnotations[frameID] = CometAnnotation(
            estimatedPoint: existing.estimatedPoint,
            resolvedPoint: existing.estimatedPoint,
            confidence: existing.confidence,
            isUserAdjusted: false,
            requiresReview: existing.estimatedPoint == nil || existing.confidence < 0.68,
            sourceFrameSize: existing.sourceFrameSize
        )
        result = nil
        errorMessage = nil
        schedulePersistence()
    }

    func openCometReviewPrerequisiteMessage() {
        errorMessage = "先运行配准，系统会自动估计彗星位置"
    }

    func clearPreparedTIFFExport() {
        pendingTIFFExport = nil
        isPresentingTIFFExporter = false
    }

    func resetProject() {
        project = StackingProject()
        result = nil
        errorMessage = nil
        pendingTIFFExport = nil
        isPresentingTIFFExporter = false
        phase = .idle
        persistTask?.cancel()

        Task {
            try? await clearRecentProject.execute()
            projectSummaries = (try? await loadProjectSummaries.execute()) ?? []
        }
    }

    private func invalidateComputedState() {
        result = nil
        errorMessage = nil

        for index in project.frames.indices {
            project.frames[index].analysis = nil
            project.frames[index].registration = nil
        }

        schedulePersistence()
    }

    private func runOperation(
        phase: ProcessingPhase,
        action: @escaping @MainActor () async throws -> Void
    ) {
        guard self.phase == .idle else { return }
        errorMessage = nil
        self.phase = phase

        Task {
            do {
                try await action()
                schedulePersistence()
            } catch {
                errorMessage = error.localizedDescription
            }

            self.phase = .idle
        }
    }

    private func schedulePersistence() {
        let snapshot = project
        persistTask?.cancel()

        persistTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            try? await persistProject.execute(project: snapshot)
            projectSummaries = (try? await loadProjectSummaries.execute()) ?? projectSummaries
        }
    }

    private func observeRecentProjectChanges() {
        NotificationCenter.default.publisher(for: LocalStackProjectRepository.recentProjectDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.hasLoadedRecentProject, !self.isWorking else { return }

                Task {
                    self.projectSummaries = (try? await self.loadProjectSummaries.execute()) ?? []
                    if let storedProject = try? await self.loadRecentProject.execute() {
                        self.project = storedProject
                    }
                }
            }
            .store(in: &cancellables)
    }
}
