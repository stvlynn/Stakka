import PhotosUI
import SwiftUI

/// Wraps the five `StackFrameSectionView` instances in a shared, collapsible
/// list. Sections that already contain frames default to expanded; empty
/// optional sections start collapsed so they don't overwhelm the detail
/// page with five "Add frame" cards.
struct StackFrameListSection: View {
    let project: StackingProject
    let isWorking: Bool
    let cometAnnotations: [UUID: CometAnnotation]
    let hasCometMode: Bool
    let onImport: (StackFrameKind, [PhotosPickerItem]) async -> Void
    let onImportFiles: (StackFrameKind, [URL]) async -> Void
    let onClear: (StackFrameKind) -> Void
    let onToggle: (UUID) -> Void
    let onRemove: (UUID) -> Void
    let onSetReference: (UUID) -> Void
    let onEditComet: (UUID) -> Void

    @State private var expandedKinds: Set<StackFrameKind> = []
    @State private var hasSeededExpansion = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(L10n.Library.frameSection)
                    .font(.stakkaSectionTitle)
                    .foregroundStyle(Color.starWhite)
                Spacer()
                Text("\(project.frames.filter(\.isEnabled).count)")
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.cosmicBlue)
                    .monospacedDigit()
            }
            .padding(.horizontal, Spacing.xs)

            ForEach(StackFrameKind.allCases) { kind in
                section(for: kind)
            }
        }
        .onAppear { seedInitialExpansion() }
        .onChange(of: project.frames.count) { _, _ in seedInitialExpansion(force: false) }
    }

    /// Renders one kind. We use a manual `DisclosureGroup`-style button +
    /// conditional content instead of `DisclosureGroup` itself so the header
    /// can match the wizard's look and feel (the system disclosure control
    /// is visually loud).
    @ViewBuilder
    private func section(for kind: StackFrameKind) -> some View {
        let frames = project.frames(of: kind)
        let count = frames.filter(\.isEnabled).count
        let isExpanded = expandedKinds.contains(kind)

        VStack(spacing: 0) {
            Button {
                toggle(kind)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: kind.symbolName)
                        .foregroundStyle(Color.cosmicBlue)
                        .frame(width: 24)
                    Text(kind.title)
                        .font(.stakkaCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.starWhite)
                    if count > 0 {
                        Text("\(count)")
                            .font(.stakkaSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.cosmicBlue)
                            .monospacedDigit()
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.cosmicBlue.opacity(0.14)))
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(AnimationPreset.smooth, value: isExpanded)
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                StackFrameSectionView(
                    kind: kind,
                    frames: frames,
                    isWorking: isWorking,
                    referenceFrameID: project.referenceFrameID,
                    cometModeEnabled: hasCometMode,
                    cometAnnotations: cometAnnotations,
                    onImport: { items in await onImport(kind, items) },
                    onImportFiles: { urls in await onImportFiles(kind, urls) },
                    onClear: { onClear(kind) },
                    onToggle: onToggle,
                    onRemove: onRemove,
                    onSetReference: onSetReference,
                    onEditComet: onEditComet
                )
                .padding(.horizontal, Spacing.xs)
                .padding(.bottom, Spacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .fill(Color.spaceSurface.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(Color.starWhite.opacity(0.06), lineWidth: 1)
        )
    }

    private func toggle(_ kind: StackFrameKind) {
        withAnimation(AnimationPreset.smooth) {
            if expandedKinds.contains(kind) {
                expandedKinds.remove(kind)
            } else {
                expandedKinds.insert(kind)
            }
        }
    }

    /// Expand sections that already have frames (so returning users see
    /// their data immediately) and keep empty optional sections collapsed.
    /// `force == false` only runs the first time to avoid clobbering the
    /// user's manual expansions.
    private func seedInitialExpansion(force: Bool = true) {
        guard !hasSeededExpansion || force else { return }
        hasSeededExpansion = true

        var next: Set<StackFrameKind> = []
        for kind in StackFrameKind.allCases {
            if kind == .light || !project.frames(of: kind).isEmpty {
                next.insert(kind)
            }
        }
        expandedKinds = next
    }
}
