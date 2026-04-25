import SwiftUI

/// Red "drop here to remove" target shown in the wizard's bottom dock while
/// the user is dragging a thumbnail. Replaces the standard nav buttons in
/// place so it can never be obscured by safe-area chrome or covered by the
/// dragged tile preview.
struct WizardDropToDeleteOverlay: View {
    /// Called with the dragged payload when the user releases inside the
    /// drop zone. The wizard resolves it back to its source binding and
    /// removes the item.
    let onDrop: (WizardFrameItemRef) -> Void

    /// Called when the user lifts their finger anywhere — both successful and
    /// cancelled drops — so the parent can collapse the dock back to nav
    /// buttons even if the drop missed the target.
    let onDragEnded: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: isHovering ? "trash.fill" : "trash")
                .font(.title3)
                .foregroundStyle(Color.starWhite)
                .scaleEffect(isHovering ? 1.15 : 1.0)
                .animation(AnimationPreset.spring, value: isHovering)

            Text(L10n.Wizard.dragToDelete)
                .font(.stakkaCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.starWhite)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: Spacing.touchTarget)
        .liquidGlassCard(cornerRadius: CornerRadius.md, tint: .galaxyPink, isInteractive: true)
        .shadow(color: .galaxyPink.opacity(isHovering ? 0.35 : 0.20), radius: isHovering ? 18 : 10, y: 6)
        .dropDestination(for: WizardFrameItemRef.self) { refs, _ in
            defer { onDragEnded() }
            guard let ref = refs.first else { return false }
            onDrop(ref)
            return true
        } isTargeted: { hovering in
            isHovering = hovering
            // When the dragged tile leaves the zone we *don't* immediately
            // collapse the dock — the user may still be hovering elsewhere.
            // The wizard's full-screen drop sentinel keeps `isDragging` true
            // until the system-level drag actually ends, at which point the
            // sentinel's `isTargeted` flips to false and the parent will
            // either receive `onDragEnded` from a successful drop above, or
            // fall back to a timed reset.
        }
        .accessibilityLabel(L10n.Wizard.dragToDelete)
        .accessibilityIdentifier("wizard.dropZone")
    }
}
