import SwiftUI

struct GalleryView: View {
    @StateObject private var viewModel: LibraryStackingViewModel
    @State private var isPresentingWizard = false
    @State private var navigateToProjectID: UUID?

    init(viewModel: LibraryStackingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                if viewModel.projectSummaries.isEmpty && !viewModel.hasProjects {
                    emptyState
                } else {
                    galleryGrid
                }

                VStack {
                    Spacer()
                    createButton
                        .padding(.bottom, Spacing.lg)
                }
            }
            .navigationTitle(L10n.Gallery.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                    viewModel.stack()
                    isPresentingWizard = false
                    navigateToProjectID = projectID
                } onCancel: {
                    isPresentingWizard = false
                }
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

                Text(L10n.Gallery.emptyHint)
                    .font(.stakkaCaption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
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
                ForEach(viewModel.projectSummaries) { summary in
                    galleryTile(summary)
                }
            }
            .padding(Spacing.md)
            .padding(.bottom, 80)
        }
    }

    private func galleryTile(_ summary: StackProjectSummary) -> some View {
        Button {
            viewModel.openProject(id: summary.id)
            navigateToProjectID = summary.id
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ZStack {
                    Color.spaceSurface
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
                .background(
                    Circle()
                        .fill(Color.cosmicBlue)
                        .shadow(color: .cosmicBlue.opacity(0.5), radius: 12, x: 0, y: 4)
                )
        }
    }
}
