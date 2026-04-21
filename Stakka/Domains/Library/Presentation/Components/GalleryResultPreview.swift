import SwiftUI

/// Full-screen preview of a completed project's stacked image. Lets the
/// gallery double as a photo browser: tapping a tile dives into the
/// rendered result, and the top-right "Open Project" button hands off to
/// the detail view for further tweaks.
struct GalleryResultPreview: View {
    let summary: StackProjectSummary
    let image: UIImage?
    let onOpenProject: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                // Zoomable image — SwiftUI 17 gesture stack kept deliberately
                // light; we only wire double-tap to reset and pinch for zoom.
                ZoomablePreview(image: image)
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(Color.textTertiary)
                    Text(L10n.Library.resultPlaceholder)
                        .font(.stakkaCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            VStack {
                topBar
                Spacer()
                bottomCaption
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.starWhite)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .background(Circle().fill(Color.black.opacity(0.4)))
            }
            .accessibilityLabel(L10n.Common.close)

            Spacer()

            Button(action: onOpenProject) {
                HStack(spacing: 6) {
                    Text(L10n.Library.openProject)
                    Image(systemName: "chevron.right")
                }
                .font(.stakkaCaption.weight(.semibold))
                .foregroundStyle(Color.starWhite)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule().fill(Color.cosmicBlue)
                )
            }
            .accessibilityIdentifier("gallery.preview.openProject")
        }
        .padding(Spacing.md)
    }

    // MARK: - Bottom caption (title + frame count)

    private var bottomCaption: some View {
        VStack(spacing: 4) {
            Text(summary.title)
                .font(.stakkaCaption.weight(.semibold))
                .foregroundStyle(Color.starWhite)
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("\(summary.lightFrameCount)")
                    .monospacedDigit()
            }
            .font(.stakkaSmall)
            .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule().fill(Color.black.opacity(0.45))
        )
        .padding(.bottom, Spacing.xl)
    }
}

/// Lightweight pinch/pan zoom wrapper. Resets with a double-tap.
private struct ZoomablePreview: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(1, min(5, steadyScale * value))
                    }
                    .onEnded { _ in
                        steadyScale = scale
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow dragging while zoomed in — otherwise the
                        // image would wander off-screen.
                        guard scale > 1 else { return }
                        offset = CGSize(
                            width: steadyOffset.width + value.translation.width,
                            height: steadyOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        steadyOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(AnimationPreset.spring) {
                    scale = 1
                    steadyScale = 1
                    offset = .zero
                    steadyOffset = .zero
                }
            }
    }
}
