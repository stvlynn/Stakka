import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Drag payload

/// Lightweight `Transferable` that identifies which thumbnail is being
/// dragged. We can't transfer the `PhotosPickerItem` itself (it isn't
/// `Transferable`), so we ship a (kind, itemKey) pair and let the wizard
/// resolve it back to an array index on drop.
struct WizardFrameItemRef: Codable, Transferable {
    let kindRaw: String
    let itemKey: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .stakkaWizardFrameRef)
    }
}

extension UTType {
    /// Custom UTI used for in-process drag-and-drop of wizard frame items.
    static let stakkaWizardFrameRef = UTType(exportedAs: "com.stakka.wizard.frameRef")
}

// MARK: - Strip

/// Horizontal scroll of 64pt thumbnails for one frame group (Light / Dark /
/// Flat / DarkFlat / Bias). Each tile is `.draggable` (long-press to begin)
/// so the user can drop it onto the wizard's bottom delete zone. Tapping a
/// tile opens a full-screen pager preview.
struct WizardThumbnailStrip: View {
    let kind: StackFrameKind
    @Binding var items: [PhotosPickerItem]
    /// Called as soon as a thumbnail's drag preview becomes visible. The
    /// wizard uses this to swap the bottom dock to its red drop zone.
    var onDragBegan: () -> Void = {}

    @StateObject private var loader = WizardThumbnailLoader()
    @State private var previewIndex: Int?

    private let tileSize: CGFloat = 64

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                        tile(for: item, at: index)
                    }
                }
                .padding(.horizontal, 2) // breathing room for shadow / stroke
            }
            .frame(height: tileSize + 4)
            .onChange(of: items) { _, newValue in
                loader.prune(keeping: newValue)
            }
            .fullScreenCover(item: Binding<PreviewState?>(
                get: { previewIndex.map { PreviewState(index: $0) } },
                set: { previewIndex = $0?.index }
            )) { state in
                WizardPhotoPreview(
                    items: items,
                    loader: loader,
                    initialIndex: min(state.index, max(items.count - 1, 0))
                )
            }
        }
    }

    @ViewBuilder
    private func tile(for item: PhotosPickerItem, at index: Int) -> some View {
        let key = WizardThumbnailLoader.cacheKey(for: item)
        let payload = WizardFrameItemRef(kindRaw: kind.rawValue, itemKey: key)

        Button {
            previewIndex = index
        } label: {
            thumbnailContent(for: item)
        }
        .buttonStyle(.plain)
        .draggable(payload) {
            // Drag preview: a slightly lifted version of the tile.
            // `onAppear` is the most reliable signal we get that a system
            // drag session has actually begun. We deliberately do NOT toggle
            // `isDragging` back to false in `onDisappear` — SwiftUI reuses
            // / re-hosts this preview as the user moves over different drop
            // targets, so disappearance is not a trustworthy "drag ended"
            // signal. The wizard collapses the dock either when a drop is
            // accepted (handleDropDelete) or when its safety timer fires.
            thumbnailContent(for: item)
                .scaleEffect(1.05)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .onAppear { onDragBegan() }
        }
        .accessibilityLabel(L10n.Accessibility.removeFrame)
    }

    @ViewBuilder
    private func thumbnailContent(for item: PhotosPickerItem) -> some View {
        ZStack {
            if let img = loader.image(for: item) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.spaceSurfaceElevated
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.textSecondary)
                    .accessibilityLabel(L10n.Wizard.loadingThumbnail)
            }
        }
        .frame(width: tileSize, height: tileSize)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                .stroke(Color.starWhite.opacity(0.08), lineWidth: 1)
        )
        .task(id: WizardThumbnailLoader.cacheKey(for: item)) {
            loader.load(item)
        }
    }
}

private struct PreviewState: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Full-screen Preview

/// Pager-style preview with horizontal swipe between imported frames.
struct WizardPhotoPreview: View {
    let items: [PhotosPickerItem]
    @ObservedObject var loader: WizardThumbnailLoader
    let initialIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    PreviewPage(item: item, loader: loader)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(Color.starWhite)
                            .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .accessibilityLabel(L10n.Wizard.previewClose)
                }
                .padding(Spacing.md)

                Spacer()

                Text(L10n.Wizard.photoIndex(current: currentIndex + 1, total: items.count))
                    .font(.stakkaCaption)
                    .foregroundStyle(Color.starWhite)
                    .monospacedDigit()
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .padding(.bottom, Spacing.xl)
            }
        }
        .onAppear {
            currentIndex = initialIndex
        }
    }
}

private struct PreviewPage: View {
    let item: PhotosPickerItem
    @ObservedObject var loader: WizardThumbnailLoader
    @State private var fullImage: UIImage?

    var body: some View {
        ZStack {
            if let img = fullImage ?? loader.image(for: item) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .tint(Color.starWhite)
            }
        }
        .task(id: WizardThumbnailLoader.cacheKey(for: item)) {
            // Try to decode the full-size image once the page becomes visible.
            // Falls back to the cached thumbnail while loading.
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                await MainActor.run { fullImage = img }
            }
        }
    }
}
