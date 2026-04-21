import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Redesigned project detail view. Visual hierarchy, from top to bottom:
///
/// 1. Hero (`StackProjectHeroView`) — result image or placeholder + title.
/// 2. Mode pickers (stacking mode, comet mode) — compact horizontal rows.
/// 3. Comet review status card (only when comet mode is on).
/// 4. Collapsible frame list (`StackFrameListSection`).
/// 5. Sticky bottom action bar (`StackActionBar`) with a single "Start
///    Stacking" CTA and in-line toasts for errors and in-progress state.
struct LibraryStackingView: View {
    @ObservedObject private var viewModel: LibraryStackingViewModel
    @State private var isPresentingCometReview = false
    @State private var cometReviewStartFrameID: UUID?
    private let openProjectID: UUID?

    init(viewModel: LibraryStackingViewModel, openProjectID: UUID? = nil) {
        self.viewModel = viewModel
        self.openProjectID = openProjectID
    }

    var body: some View {
        ZStack {
            Color.spaceBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        StackProjectHeroView(
                            project: viewModel.project,
                            result: viewModel.result,
                            onSave: viewModel.saveResult,
                            onExportTIFF: viewModel.prepareResultTIFFExport
                        )

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

                        StackFrameListSection(
                            project: viewModel.project,
                            isWorking: viewModel.isWorking,
                            cometAnnotations: viewModel.project.cometAnnotations,
                            hasCometMode: viewModel.hasCometModeEnabled,
                            onImport: { kind, items in
                                await viewModel.importFrames(from: items, kind: kind)
                            },
                            onImportFiles: { kind, urls in
                                await viewModel.importFrames(from: urls, kind: kind)
                            },
                            onClear: { kind in viewModel.clearGroup(kind) },
                            onToggle: { viewModel.toggleFrame($0) },
                            onRemove: { viewModel.removeFrame($0) },
                            onSetReference: { viewModel.setReferenceFrame($0) },
                            onEditComet: { openCometReview(startingFrameID: $0) }
                        )
                    }
                    .padding(Spacing.md)
                    .padding(.bottom, Spacing.lg) // breathing room above sticky bar
                }

                StackActionBar(
                    phase: viewModel.phase,
                    errorMessage: viewModel.errorMessage,
                    progress: viewModel.pipelineProgress,
                    isEnabled: viewModel.canRunPipeline,
                    action: viewModel.runPipeline
                )
            }
        }
        .navigationTitle(L10n.Library.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if let openProjectID {
                viewModel.openProject(id: openProjectID)
                // If the project already has a persisted result, surface it
                // immediately so the hero section shows the stacked image
                // even before any action.
                await viewModel.restoreResult(for: openProjectID)
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
        // Project browser and "New" toolbar entries were removed per the
        // redesign — navigation is handled entirely by the gallery and the
        // system back button.
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
