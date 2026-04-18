import SwiftUI
import PhotosUI

struct LibraryStackingView: View {
    @StateObject private var viewModel = LibraryStackingViewModel()

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
                            imageGridView

                            if viewModel.isStacking {
                                stackingProgressView
                            }

                            if let result = viewModel.stackedImage {
                                stackedResultView(result: result)
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

    private var imageGridView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label("\(viewModel.selectedImages.count)", systemImage: "photo.on.rectangle.angled")
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)

                Spacer()

                Button {
                    withAnimation(AnimationPreset.smooth) {
                        viewModel.selectedItems.removeAll()
                        viewModel.selectedImages.removeAll()
                        viewModel.stackedImage = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.galaxyPink)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.sm)], spacing: Spacing.sm) {
                ForEach(viewModel.selectedImages.indices, id: \.self) { index in
                    Image(uiImage: viewModel.selectedImages[index])
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .continuousCorners(CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .stroke(Color.cosmicBlue.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.spaceSurface.opacity(0.3))
        .continuousCorners(CornerRadius.lg)
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

    private func stackedResultView(result: UIImage) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.cosmicBlue)
                    .breathingGlow(color: .cosmicBlue, radius: 4)

                Text("堆栈完成")
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)

                Spacer()
            }

            Image(uiImage: result)
                .resizable()
                .scaledToFit()
                .continuousCorners(CornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.cosmicBlue, .nebulaPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .cosmicBlue.opacity(0.3), radius: 20)

            Button {
                viewModel.saveStackedImage()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("保存")
                }
                .font(.stakkaCaption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cosmicBlue)
        }
        .padding(Spacing.md)
        .glassCard()
    }
}
