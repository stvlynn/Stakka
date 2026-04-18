import SwiftUI
import PhotosUI

struct LibraryStackingView: View {
    @StateObject private var viewModel: LibraryStackingViewModel

    init(viewModel: LibraryStackingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        if viewModel.selectedImages.isEmpty {
                            emptyStateView
                        } else {
                            PhotoGridView(images: viewModel.selectedImages) {
                                viewModel.clearSelection()
                            }

                            if viewModel.isStacking {
                                stackingProgressView
                            }

                            if let result = viewModel.stackedImage {
                                StackedResultCard(image: result) {
                                    viewModel.saveStackedImage()
                                }
                            }
                        }
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("图库堆栈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $viewModel.selectedItems, maxSelectionCount: 100, matching: .images) {
                        Image(systemName: "photo.badge.plus")
                            .foregroundStyle(Color.cosmicBlue)
                    }
                }

                if !viewModel.selectedImages.isEmpty && viewModel.stackedImage == nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            viewModel.stackImages()
                        } label: {
                            HStack {
                                Image(systemName: "square.stack.3d.up.fill")
                                Text("开始堆栈")
                            }
                            .font(.stakkaCaption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cosmicBlue)
                        .disabled(viewModel.isStacking)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.spaceSurface.opacity(0.3))
                    .frame(width: 120, height: 120)

                Image(systemName: "photo.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.textTertiary)
            }

            VStack(spacing: Spacing.xs) {
                Text("选择照片开始堆栈")
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stackingProgressView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(.cosmicBlue)
                .scaleEffect(1.5)

            Text("处理中...")
                .font(.stakkaCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .glassCard()
    }
}
