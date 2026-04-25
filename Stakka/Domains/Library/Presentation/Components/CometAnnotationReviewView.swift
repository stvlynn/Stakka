import SwiftUI

struct CometAnnotationReviewView: View {
    let frames: [StackFrame]
    let annotations: [UUID: CometAnnotation]
    let startingFrameID: UUID?
    let onUpdatePoint: (UUID, PixelPoint) -> Void
    let onUseEstimated: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                if let currentFrame {
                    GlassEffectContainer(spacing: Spacing.md) {
                        VStack(spacing: Spacing.md) {
                            header(for: currentFrame)
                            annotationCanvas(for: currentFrame)
                            navigationControls
                        }
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle(L10n.Library.reviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let startingFrameID,
                   let index = frames.firstIndex(where: { $0.id == startingFrameID }) {
                    currentIndex = index
                }
            }
        }
    }

    private var currentFrame: StackFrame? {
        guard frames.indices.contains(currentIndex) else { return nil }
        return frames[currentIndex]
    }

    private func header(for frame: StackFrame) -> some View {
        let annotation = annotations[frame.id]

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(frame.name)
                        .font(.stakkaHeadline)
                        .foregroundStyle(Color.starWhite)

                    if let annotation {
                        Text(annotation.requiresReview ? L10n.Library.reviewNeedsCheck : L10n.Library.reviewConfirmed)
                            .font(.stakkaCaption)
                            .foregroundStyle(annotation.requiresReview ? Color.galaxyPink : Color.appAccent)
                    }
                }

                Spacer()

                Text(L10nFormat.ratio(currentIndex + 1, frames.count))
                    .font(.stakkaCaption)
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
            }

            if let annotation {
                HStack(spacing: Spacing.sm) {
                    metricChip(symbol: "scope", value: L10nFormat.decimal(annotation.confidence, digits: 2))
                    metricChip(symbol: "hand.point.up.left.fill", value: annotation.isUserAdjusted ? L10n.Library.reviewManual : L10n.Library.reviewAuto)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .glassCard()
    }

    private func annotationCanvas(for frame: StackFrame) -> some View {
        let annotation = annotations[frame.id]

        return VStack(spacing: Spacing.md) {
            CometAnnotationCanvas(
                image: frame.image,
                estimatedPoint: annotation?.estimatedPoint,
                resolvedPoint: annotation?.resolvedPoint
            ) { point in
                onUpdatePoint(frame.id, point)
            }
            .frame(maxHeight: .infinity)
            .glassCard()

            if annotation?.estimatedPoint != nil {
                Button {
                    onUseEstimated(frame.id)
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text(L10n.Library.useEstimated)
                    }
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                }
                .buttonStyle(.glass)
                .tint(.starWhite)
            }
        }
    }

    private var navigationControls: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                currentIndex = max(0, currentIndex - 1)
            } label: {
                controlLabel(L10n.Library.previousFrame, symbol: "chevron.left")
            }
            .buttonStyle(.glass)
            .disabled(currentIndex == 0)

            Button {
                currentIndex = min(frames.count - 1, currentIndex + 1)
            } label: {
                controlLabel(L10n.Library.nextFrame, symbol: "chevron.right")
            }
            .buttonStyle(.glass)
            .disabled(currentIndex == frames.count - 1)
        }
    }

    private func controlLabel(_ title: String, symbol: String) -> some View {
        HStack {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.stakkaCaption)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }

    private func metricChip(symbol: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(value)
                .monospacedDigit()
        }
        .font(.stakkaSmall)
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .liquidGlassPill()
    }
}

private struct CometAnnotationCanvas: View {
    let image: UIImage
    let estimatedPoint: PixelPoint?
    let resolvedPoint: PixelPoint?
    let onSetPoint: (PixelPoint) -> Void

    @State private var zoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var lastZoomScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let baseRect = fittedRect(in: proxy.size)
            let displayRect = transformedRect(from: baseRect)

            ZStack {
                Color.clear

                Image(uiImage: image)
                    .resizable()
                    .frame(width: baseRect.width, height: baseRect.height)
                    .scaleEffect(zoomScale)
                    .offset(panOffset)

                if let estimatedPoint {
                    marker(for: estimatedPoint, in: displayRect, color: .galaxyPink, filled: false)
                }

                if let resolvedPoint {
                    marker(for: resolvedPoint, in: displayRect, color: .appAccent, filled: true)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        panOffset = CGSize(
                            width: lastPanOffset.width + value.translation.width,
                            height: lastPanOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastPanOffset = panOffset
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoomScale = min(max(lastZoomScale * value, 1), 5)
                    }
                    .onEnded { _ in
                        lastZoomScale = zoomScale
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard let point = imagePoint(from: value.location, in: displayRect) else { return }
                        onSetPoint(point)
                    }
            )
        }
    }

    private func fittedRect(in containerSize: CGSize) -> CGRect {
        let scale = min(containerSize.width / image.size.width, containerSize.height / image.size.height)
        let width = image.size.width * scale
        let height = image.size.height * scale
        return CGRect(
            x: (containerSize.width - width) / 2,
            y: (containerSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func transformedRect(from baseRect: CGRect) -> CGRect {
        let scaledWidth = baseRect.width * zoomScale
        let scaledHeight = baseRect.height * zoomScale
        return CGRect(
            x: baseRect.midX - (scaledWidth / 2) + panOffset.width,
            y: baseRect.midY - (scaledHeight / 2) + panOffset.height,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    private func imagePoint(from location: CGPoint, in displayRect: CGRect) -> PixelPoint? {
        guard displayRect.contains(location) else { return nil }

        let normalizedX = (location.x - displayRect.minX) / displayRect.width
        let normalizedY = (location.y - displayRect.minY) / displayRect.height
        return PixelPoint(
            x: max(0, min(Double(image.size.width), Double(normalizedX) * image.size.width)),
            y: max(0, min(Double(image.size.height), Double(normalizedY) * image.size.height))
        )
    }

    private func marker(for point: PixelPoint, in displayRect: CGRect, color: Color, filled: Bool) -> some View {
        let position = CGPoint(
            x: displayRect.minX + (CGFloat(point.x / image.size.width) * displayRect.width),
            y: displayRect.minY + (CGFloat(point.y / image.size.height) * displayRect.height)
        )

        return ZStack {
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: 18, height: 18)

            if filled {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
        }
        .position(position)
    }
}
