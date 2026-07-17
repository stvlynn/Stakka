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

    /// Vertical drag offset while the user is pulling the image down to
    /// dismiss (Photos-style). The backdrop and chrome fade out as the
    /// image travels.
    @State private var dismissOffset: CGSize = .zero
    /// Mirrors the preview's zoom state so the pull-to-dismiss gesture stays
    /// out of the way while the user is panning a zoomed-in image.
    @State private var isZoomed = false

    private var dismissProgress: CGFloat {
        min(abs(dismissOffset.height) / 320, 1)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(1 - Double(dismissProgress) * 0.6)
                .ignoresSafeArea()

            if let image {
                ZoomablePreview(image: image, isZoomed: $isZoomed)
                    .offset(dismissOffset)
                    .scaleEffect(1 - dismissProgress * 0.12)
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
            .opacity(1 - Double(dismissProgress))
        }
        .simultaneousGesture(dismissDragGesture)
        .preferredColorScheme(.dark)
    }

    /// Pull-down-to-dismiss. A quick flick dismisses regardless of distance
    /// (velocity check), a slow drag needs to travel far enough; anything
    /// else springs back.
    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Only vertical pulls on the un-zoomed image participate —
                // while zoomed in, dragging pans the image instead.
                guard !isZoomed,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                dismissOffset = CGSize(width: value.translation.width * 0.4, height: value.translation.height)
            }
            .onEnded { value in
                guard !isZoomed else { return }
                let travel = value.translation.height
                let velocity = value.predictedEndTranslation.height - value.translation.height
                if travel > 140 || velocity > 220 {
                    onDismiss()
                } else {
                    withAnimation(AnimationPreset.spring) {
                        dismissOffset = .zero
                    }
                }
            }
    }

    // MARK: - Top bar

    private var topBar: some View {
        GlassEffectContainer(spacing: Spacing.sm) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.starWhite)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                        .liquidGlass(in: Circle(), isInteractive: true)
                }
                .buttonStyle(.pressable)
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
                }
                .buttonStyle(.glassProminent)
                .tint(.appAccent)
                .accessibilityIdentifier("gallery.preview.openProject")
            }
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
        .liquidGlassPill()
        .padding(.bottom, Spacing.xl)
    }
}

/// Lightweight pinch/pan zoom wrapper. Double-tap toggles between fit and
/// a 2.5× close-up (Photos behavior); pinch zooms freely up to 5×.
private struct ZoomablePreview: View {
    let image: UIImage
    @Binding var isZoomed: Bool

    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    private let doubleTapScale: CGFloat = 2.5

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
                        syncZoomState()
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
                    if steadyScale > 1 {
                        scale = 1
                        steadyScale = 1
                        offset = .zero
                        steadyOffset = .zero
                    } else {
                        scale = doubleTapScale
                        steadyScale = doubleTapScale
                    }
                }
                syncZoomState()
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isZoomed)
    }

    private func syncZoomState() {
        let zoomedNow = steadyScale > 1.01
        if zoomedNow != isZoomed {
            isZoomed = zoomedNow
        }
        if !zoomedNow {
            withAnimation(AnimationPreset.spring) {
                offset = .zero
                steadyOffset = .zero
            }
        }
    }
}
