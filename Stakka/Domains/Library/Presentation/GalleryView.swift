import SwiftUI

struct GalleryView: View {
    @StateObject private var viewModel: LibraryStackingViewModel
    @State private var isPresentingWizard = false
    @State private var navigateToProjectID: UUID?
    @State private var previewSummary: StackProjectSummary?

    init(viewModel: LibraryStackingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Projects shown in the gallery grid. We filter on `resultThumbnailURL`
    /// so only completed stacks surface here — projects that were started
    /// but never stacked (e.g. the user closed the wizard halfway) stay
    /// hidden until they produce a result.
    private var completedSummaries: [StackProjectSummary] {
        viewModel.projectSummaries.filter { $0.resultThumbnailURL != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                if completedSummaries.isEmpty {
                    emptyState
                } else {
                    galleryGrid
                }

                VStack {
                    Spacer()
                    createButton
                        .padding(.bottom, Spacing.xl + Spacing.sm)
                }
            }
            .navigationTitle(L10n.Gallery.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.loadRecentProjectIfNeeded()
            }
            .navigationDestination(item: $navigateToProjectID) { projectID in
                LibraryStackingView(viewModel: viewModel, openProjectID: projectID)
            }
            .fullScreenCover(isPresented: $isPresentingWizard) {
                ProjectCreationWizardView { mode, frames in
                    let projectID = await viewModel.createProjectFromWizard(mode: mode, frames: frames)
                    isPresentingWizard = false
                    navigateToProjectID = projectID
                    // Kick off the pipeline after the detail view has a
                    // chance to mount so progress updates are observed.
                    viewModel.runPipeline()
                } onCancel: {
                    isPresentingWizard = false
                }
            }
            .fullScreenCover(item: $previewSummary) { summary in
                GalleryResultPreview(
                    summary: summary,
                    image: viewModel.thumbnailCache[summary.id],
                    onOpenProject: {
                        previewSummary = nil
                        navigateToProjectID = summary.id
                    },
                    onDismiss: { previewSummary = nil }
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            VStack(spacing: Spacing.sm) {
                Text(L10n.Gallery.empty)
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)
                    .multilineTextAlignment(.center)

                HStack(spacing: Spacing.xs) {
                    Text(L10n.Gallery.emptyHint)
                        .multilineTextAlignment(.center)
                    Image(systemName: "arrow.down")
                        .imageScale(.small)
                }
                .font(.stakkaCaption)
                .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(Spacing.xl)
    }

    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.sm),
                    GridItem(.flexible(), spacing: Spacing.sm)
                ],
                spacing: Spacing.sm
            ) {
                ForEach(completedSummaries) { summary in
                    galleryTile(summary)
                }
            }
            .padding(Spacing.md)
            .padding(.bottom, 80)
        }
    }

    private func galleryTile(_ summary: StackProjectSummary) -> some View {
        Button {
            // Gallery tap → full-screen result preview (not the detail
            // page). The preview's "Open Project" CTA routes to the
            // detail view on demand.
            previewSummary = summary
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ZStack {
                    Color.liquidGlassSurface
                        .aspectRatio(1, contentMode: .fit)

                    if let thumbnail = viewModel.thumbnailCache[summary.id] {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                            .clipped()
                    } else {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.textMuted)
                    }
                }
                .continuousCorners(CornerRadius.md)
                .onAppear {
                    viewModel.loadThumbnail(for: summary.id)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.title)
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.starWhite)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                        Text("\(summary.lightFrameCount)")
                            .monospacedDigit()
                    }
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.textTertiary)
                }
                .padding(.horizontal, Spacing.xs)
            }
            .padding(Spacing.sm)
            .liquidGlassCard(cornerRadius: CornerRadius.lg, isInteractive: true)
        }
        .buttonStyle(.plain)
    }

    private var createButton: some View {
        Button {
            isPresentingWizard = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.starWhite)
                .frame(width: 56, height: 56)
                .liquidGlass(in: Circle(), tint: .appAccent, isInteractive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Gallery.createProject)
        .accessibilityIdentifier("gallery.fab.create")
    }
}
