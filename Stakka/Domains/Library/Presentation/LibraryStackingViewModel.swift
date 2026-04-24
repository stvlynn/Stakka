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
                return L10n.Library.ready
            case .analyzing:
                return L10n.Library.analyze
            case .registering:
                return L10n.Library.register
            case .stacking:
                return L10n.Library.stack
            case .saving:
                return L10n.Common.save
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
    @Published private(set) var thumbnailCache: [UUID: UIImage] = [:]
    /// Live pipeline progress. `nil` while idle; populated with per-stage
    /// frame counts and timing while a pipeline run is in flight so the
    /// detail view can render a real progress bar, ETA, and throughput.
    @Published private(set) var pipelineProgress: PipelineProgress?

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
    private let persistStackResult: PersistStackResultUseCase
    private let loadStackResult: LoadStackResultUseCase
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
        prepareTIFFExport: PrepareStackedTIFFExportUseCase,
        persistStackResult: PersistStackResultUseCase,
        loadStackResult: LoadStackResultUseCase
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
        self.persistStackResult = persistStackResult
        self.loadStackResult = loadStackResult
        observeRecentProjectChanges()
    }

    var isWorking: Bool {
        phase != .idle
    }

    var hasProjects: Bool {
        !projectSummaries.isEmpty
    }

    func loadThumbnail(for projectID: UUID) {
        guard thumbnailCache[projectID] == nil else { return }

        Task {
            // Prefer the persisted stack result so the gallery shows the
            // final image for completed projects. If no result exists, we
            // simply leave the entry unset — the gallery now filters out
            // projects without a result image anyway.
            if let resultImage = try? await loadStackResult.execute(projectID: projectID) {
                thumbnailCache[projectID] = resultImage
            }
        }
    }

    func createProjectFromWizard(mode: StackingMode, frames: [WizardFrameGroup]) async -> UUID {
        let newProject = StackingProject(
            title: L10n.Project.newTitle(at: Date()),
            mode: mode
        )
        project = newProject
        result = nil
        errorMessage = nil
        pendingTIFFExport = nil

        for group in frames {
            let imported = await importPhotos.execute(from: group.items, kind: group.kind)
            project.frames.append(contentsOf: imported)
        }
        invalidateComputedState()

        return newProject.id
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
        project = StackingProject(title: L10n.Project.newTitle(at: Date()))
        result = nil
        errorMessage = nil
        pendingTIFFExport = nil
        schedulePersistence()
    }

    func openProject(id: UUID) {
        Task {
            _ = await openProjectAndRestore(id: id)
        }
    }

    @discardableResult
    func openProjectAndRestore(id: UUID) async -> Bool {
        do {
            guard let loadedProject = try await loadProject.execute(id: id) else {
                return false
            }

            project = loadedProject
            result = nil
            errorMessage = nil
            pendingTIFFExport = nil

            try await markRecentProjectUseCase.execute(id: id)
            projectSummaries = try await loadProjectSummaries.execute()
            await restoreResult(for: id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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

    /// One-shot pipeline driven by the redesigned detail view's single
    /// "Start Stacking" button. Runs analyze → register → stack, reporting
    /// per-frame progress and persisting the result so the gallery can
    /// display completed projects.
    func runPipeline() {
        guard phase == .idle else { return }
        guard project.enabledLightFrames.count >= 2 else { return }

        errorMessage = nil
        phase = .analyzing
        let projectID = project.id
        // Fresh progress tracker — starts at 0/0 so the UI can render a
        // "starting…" state before any frame reports back.
        pipelineProgress = PipelineProgress(stage: .analyzing, completed: 0, total: 0, startedAt: Date())

        // `@Sendable` callback bridging actor-isolated processor → main
        // actor ViewModel state.
        let reporter: StackingProgressReporter = { [weak self] stage, completed, total in
            Task { @MainActor [weak self] in
                self?.pipelineProgress = PipelineProgress(
                    stage: stage,
                    completed: completed,
                    total: total,
                    startedAt: self?.pipelineProgress?.startedAt(for: stage) ?? Date()
                )
            }
        }

        Task {
            do {
                let analyzed = try await self.analyzeProject.execute(project: self.project, progress: reporter)
                self.project = analyzed

                self.phase = .registering
                let registered = try await self.registerProject.execute(project: analyzed, progress: reporter)
                self.project = registered

                self.phase = .stacking
                let stacked = try await self.runStacking.execute(project: registered, progress: reporter)
                self.result = stacked

                // Persist the completed project and result immediately. The
                // gallery filters on result-bearing summaries, so relying on
                // the debounced autosave here leaves the completed preview
                // invisible until a later refresh.
                self.persistTask?.cancel()
                self.persistTask = nil
                try await self.persistProject.execute(project: registered)
                try await self.persistStackResult.execute(image: stacked.image, projectID: projectID)
                self.thumbnailCache[projectID] = stacked.image
                self.projectSummaries = try await self.loadProjectSummaries.execute()
            } catch {
                self.errorMessage = error.localizedDescription
            }

            self.phase = .idle
            self.pipelineProgress = nil
        }
    }

    /// `true` when there are enough light frames to kick off the pipeline.
    var canRunPipeline: Bool {
        !isWorking && project.enabledLightFrames.count >= 2
    }

    /// Loads the previously persisted stack result for a given project and
    /// promotes it to the current session so the detail view can display it
    /// without re-running the pipeline. No-op if the project has no
    /// persisted result yet.
    func restoreResult(for projectID: UUID) async {
        guard project.id == projectID else { return }
        if result != nil { return }
        guard let image = try? await loadStackResult.execute(projectID: projectID) else { return }
        result = LibraryStackingViewModel.restoredResult(image: image, for: project)
    }

    /// Rebuilds a minimal `StackingResult` from a project + previously
    /// persisted image. We can't reconstruct per-frame `tiffData`, so
    /// export-as-TIFF is disabled until a fresh run happens; this is
    /// surfaced in the UI by leaving the TIFF button hidden unless the
    /// result was produced during the current session.
    private static func restoredResult(image: UIImage, for project: StackingProject) -> StackingResult {
        let lightCount = project.enabledLightFrames.count
        let referenceName = project.referenceFrameID.flatMap { project.frame(id: $0)?.name } ?? ""
        let recap = StackingRecap(
            referenceFrameName: referenceName,
            usedLightFrameCount: lightCount,
            darkFrameCount: project.frames(of: .dark).filter(\.isEnabled).count,
            flatFrameCount: project.frames(of: .flat).filter(\.isEnabled).count,
            darkFlatFrameCount: project.frames(of: .darkFlat).filter(\.isEnabled).count,
            biasFrameCount: project.frames(of: .bias).filter(\.isEnabled).count,
            cometMode: project.cometMode,
            annotatedFrameCount: project.cometAnnotations.count,
            manuallyAdjustedFrameCount: project.cometAnnotations.values.filter(\.isUserAdjusted).count
        )
        return StackingResult(
            image: image,
            tiffData: Data(),
            frameCount: lightCount,
            mode: project.mode,
            recap: recap
        )
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
        errorMessage = L10n.Library.cometReviewPrerequisite
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

// MARK: - Pipeline Progress

/// Live progress snapshot consumed by the detail view's status bar. Carries
/// enough to derive fraction, ETA, and frames-per-second without additional
/// timers inside the View layer.
struct PipelineProgress: Equatable {
    let stage: StackingProgressStage
    let completed: Int
    let total: Int
    /// When the *current* stage started. Resets on stage change so ETA
    /// estimates don't blend numbers from earlier (differently-sized)
    /// stages.
    let startedAt: Date

    /// Overall fraction within the current stage, clamped to `0...1`.
    var stageFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }

    /// Frames processed per second within the current stage. Returns 0
    /// until at least one frame has completed (avoids an infinity).
    var framesPerSecond: Double {
        let elapsed = max(0.001, Date().timeIntervalSince(startedAt))
        guard completed > 0 else { return 0 }
        return Double(completed) / elapsed
    }

    /// Estimated time remaining within the current stage, based on the
    /// observed throughput so far. `nil` while we don't have enough data
    /// (either no progress yet, or total is unknown).
    var estimatedRemaining: TimeInterval? {
        guard total > 0, completed > 0, completed < total else { return nil }
        let rate = framesPerSecond
        guard rate > 0 else { return nil }
        return Double(total - completed) / rate
    }

    /// Returns the stored `startedAt` when the stage hasn't changed, or the
    /// current time (to reset elapsed measurement) when the stage just
    /// transitioned. Used when the ViewModel merges callback updates.
    func startedAt(for incomingStage: StackingProgressStage) -> Date {
        incomingStage == stage ? startedAt : Date()
    }
}
