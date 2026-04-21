import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct LibraryStackingView: View {
    @ObservedObject private var viewModel: LibraryStackingViewModel
    @State private var isPresentingCometReview = false
    @State private var cometReviewStartFrameID: UUID?
    @State private var isPresentingProjectBrowser = false
    private let openProjectID: UUID?

    init(viewModel: LibraryStackingViewModel, openProjectID: UUID? = nil) {
        self.viewModel = viewModel
        self.openProjectID = openProjectID
    }

    var body: some View {
        ZStack {
            Color.spaceBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    StackProjectSummaryCard(project: viewModel.project)

                    if viewModel.project.frames.isEmpty {
                        introCard
                    }

                    StackingModePickerView(
                        selectedMode: viewModel.project.mode,
                        onSelect: viewModel.setMode
                    )

                    CometModePickerView(
                        selectedMode: viewModel.project.cometMode,
                        onSelect: viewModel.setCometMode
                    )

                    if let cometMode = viewModel.project.cometMode {
                        CometReviewStatusCard(
                            mode: cometMode,
                            reviewedCount: viewModel.cometReviewedCount,
                            totalCount: viewModel.cometReviewFrameIDs.count,
                            needsReviewCount: viewModel.project.enabledFramesNeedingCometReview.count,
                            onReview: {
                                openCometReview(startingFrameID: viewModel.firstCometReviewFrameID)
                            }
                        )
                    }

                    if viewModel.phase != .idle {
                        ProcessingStatusCard(phase: viewModel.phase)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorCard(message: errorMessage)
                    }

                    ForEach(StackFrameKind.allCases) { kind in
                        StackFrameSectionView(
                            kind: kind,
                            frames: viewModel.project.frames(of: kind),
                            isWorking: viewModel.isWorking,
                            referenceFrameID: viewModel.project.referenceFrameID,
                            cometModeEnabled: viewModel.hasCometModeEnabled,
                            cometAnnotations: viewModel.project.cometAnnotations,
                            onImport: { items in
                                await viewModel.importFrames(from: items, kind: kind)
                            },
                            onImportFiles: { urls in
                                await viewModel.importFrames(from: urls, kind: kind)
                            },
                            onClear: {
                                viewModel.clearGroup(kind)
                            },
                            onToggle: { frameID in
                                viewModel.toggleFrame(frameID)
                            },
                            onRemove: { frameID in
                                viewModel.removeFrame(frameID)
                            },
                            onSetReference: { frameID in
                                viewModel.setReferenceFrame(frameID)
                            },
                            onEditComet: { frameID in
                                openCometReview(startingFrameID: frameID)
                            }
                        )
                    }

                    actionPanel

                    if let result = viewModel.result {
                        StackedResultCard(result: result) {
                            viewModel.saveResult()
                        } onExportTIFF: {
                            viewModel.prepareResultTIFFExport()
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }
        .navigationTitle(L10n.Library.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if let openProjectID {
                viewModel.openProject(id: openProjectID)
            } else {
                await viewModel.loadRecentProjectIfNeeded()
            }
        }
        .fileExporter(
            isPresented: $viewModel.isPresentingTIFFExporter,
            document: viewModel.pendingTIFFExport.map { StackedTIFFDocument(data: $0.data) },
            contentType: .tiff,
            defaultFilename: viewModel.pendingTIFFExport?.filename
        ) { _ in
            viewModel.clearPreparedTIFFExport()
        }
        .sheet(isPresented: $isPresentingCometReview) {
            CometAnnotationReviewView(
                frames: viewModel.project.enabledLightFrames,
                annotations: viewModel.project.cometAnnotations,
                startingFrameID: cometReviewStartFrameID,
                onUpdatePoint: { frameID, point in
                    viewModel.markCometPoint(point, for: frameID)
                },
                onUseEstimated: { frameID in
                    viewModel.restoreEstimatedCometPoint(for: frameID)
                }
            )
        }
        .sheet(isPresented: $isPresentingProjectBrowser) {
            StackProjectBrowserView(
                currentProjectID: viewModel.project.id,
                summaries: viewModel.projectSummaries,
                onOpen: viewModel.openProject,
                onDuplicate: viewModel.duplicateProject,
                onDelete: viewModel.deleteProject,
                onCreate: viewModel.createNewProject
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresentingProjectBrowser = true
                } label: {
                    Image(systemName: "books.vertical")
                        .foregroundStyle(Color.starWhite)
                }
                .accessibilityLabel(L10n.Accessibility.openProjects)
            }

            if !viewModel.project.frames.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.Common.new) {
                        viewModel.createNewProject()
                    }
                    .foregroundStyle(Color.galaxyPink)
                }
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.cosmicBlue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Library.introTitle)
                        .font(.stakkaHeadline)
                        .foregroundStyle(Color.starWhite)
                    Text(L10n.Library.introSubtitle)
                        .font(.stakkaCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .glassCard()
    }

    private var actionPanel: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                actionButton(
                    title: L10n.Library.analyze,
                    symbol: "viewfinder",
                    isPrimary: false,
                    isDisabled: viewModel.isWorking || viewModel.project.enabledLightFrames.isEmpty,
                    action: viewModel.analyze
                )

                actionButton(
                    title: L10n.Library.register,
                    symbol: "scope",
                    isPrimary: false,
                    isDisabled: viewModel.isWorking || viewModel.project.enabledLightFrames.count < 2,
                    action: viewModel.register
                )

                actionButton(
                    title: L10n.Library.stack,
                    symbol: "square.stack.3d.up.fill",
                    isPrimary: true,
                    isDisabled: viewModel.isWorking || viewModel.project.enabledLightFrames.count < 2,
                    action: viewModel.stack
                )
            }

            Text(actionHint)
                .font(.stakkaSmall)
                .foregroundStyle(Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(2)
        }
        .padding(Spacing.md)
        .glassCard()
    }

    private func actionButton(
        title: String,
        symbol: String,
        isPrimary: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.stakkaSmall)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .foregroundStyle(isDisabled ? Color.textMuted : (isPrimary ? Color.starWhite : Color.starWhite))
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .fill(
                        isDisabled
                            ? Color.spaceSurfaceElevated.opacity(0.4)
                            : (isPrimary ? Color.cosmicBlue : Color.spaceSurfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .stroke(
                                isDisabled ? Color.clear : (isPrimary ? Color.cosmicBlue.opacity(0.5) : Color.starWhite.opacity(0.08)),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: isPrimary && !isDisabled ? Color.cosmicBlue.opacity(0.35) : .clear,
                radius: 8, x: 0, y: 4
            )
        }
        .disabled(isDisabled)
        .animation(AnimationPreset.transition, value: isDisabled)
    }

    private func errorCard(message: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.galaxyPink)

            Text(message)
                .font(.stakkaCaption)
                .foregroundStyle(Color.starWhite)
                .lineSpacing(2)

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Color.galaxyPink.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(Color.galaxyPink.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.galaxyPink.opacity(0.2), radius: 8, x: 0, y: 2)
    }

    private var actionHint: String {
        if viewModel.project.cometMode != nil {
            return L10n.Library.cometHint
        }

        return L10n.Library.referenceHint(lightTitle: StackFrameKind.light.title)
    }

    private func openCometReview(startingFrameID: UUID?) {
        guard viewModel.project.cometMode != nil else {
            return
        }

        guard !viewModel.project.cometAnnotations.isEmpty else {
            viewModel.openCometReviewPrerequisiteMessage()
            return
        }

        cometReviewStartFrameID = startingFrameID
        isPresentingCometReview = true
    }
}
