import SwiftUI

/// Unified top-of-page hero for the project detail view. Replaces the old
/// separate `StackProjectSummaryCard` + mid-scroll `StackedResultCard` combo
/// with a single, prominent block:
///
/// * No result yet → a space-background placeholder with the project title
///   and a compact frame-count row.
/// * Result available → the stacked image rendered large, plus save/export
///   CTAs.
///
/// Gives the screen an anchor and makes it obvious at a glance whether
/// the project has been stacked.
struct StackProjectHeroView: View {
    let project: StackingProject
    let result: StackingResult?
    let onSave: () -> Void
    let onExportTIFF: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            mediaBlock
            if result != nil {
                resultActions
            } else {
                frameCountStrip
            }
        }
        .padding(Spacing.md)
        .glassCard()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(project.title)
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)
                    .lineLimit(1)

                if let cometMode = project.cometMode {
                    subtitleRow(symbol: cometMode.symbolName,
                                text: cometMode.description,
                                tint: .nebulaPurple)
                } else if let referenceFrameName {
                    subtitleRow(symbol: "scope",
                                text: referenceFrameName,
                                tint: .textSecondary)
                } else {
                    subtitleRow(symbol: "sparkles",
                                text: L10n.Library.autoReferenceHint(lightTitle: StackFrameKind.light.title),
                                tint: .textSecondary)
                }
            }

            Spacer()

            if let result {
                Text(result.mode.title)
                    .font(.stakkaSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.cosmicBlue)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Color.cosmicBlue.opacity(0.14))
                    .continuousCorners(CornerRadius.sm)
            }
        }
    }

    private func subtitleRow(symbol: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text).lineLimit(1)
        }
        .font(.stakkaSmall)
        .foregroundStyle(tint)
    }

    // MARK: - Media (result image or placeholder)

    @ViewBuilder
    private var mediaBlock: some View {
        if let result {
            Image(uiImage: result.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .continuousCorners(CornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.cosmicBlue, .nebulaPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .cosmicBlue.opacity(0.25), radius: 18)
        } else {
            placeholderMedia
        }
    }

    private var placeholderMedia: some View {
        ZStack {
            LinearGradient(
                colors: [Color.spaceSurfaceElevated.opacity(0.9), Color.spaceSurface.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.cosmicBlue)
                    .breathingGlow(color: .cosmicBlue, radius: 6)
                Text(L10n.Library.resultPlaceholder)
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.starWhite)
                    .multilineTextAlignment(.center)
                Text(L10n.Library.resultPlaceholderHint)
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(Spacing.lg)
        }
        .frame(height: 200)
        .continuousCorners(CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(Color.starWhite.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Frame count row (no-result state)

    /// Compact icon+number row mirroring the old summary card but laid out
    /// more calmly. Only shown when no result exists, so it doesn't compete
    /// with the stacked image for attention.
    private var frameCountStrip: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(StackFrameKind.allCases) { kind in
                VStack(spacing: 4) {
                    Image(systemName: kind.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.cosmicBlue)
                    Text("\(project.frames(of: kind).filter(\.isEnabled).count)")
                        .font(.stakkaCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.starWhite)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .background(Color.spaceSurface.opacity(0.55))
                .continuousCorners(CornerRadius.sm)
                .accessibilityLabel("\(kind.title): \(project.frames(of: kind).filter(\.isEnabled).count)")
            }
        }
    }

    // MARK: - Result actions

    private var resultActions: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onSave) {
                actionLabel(symbol: "square.and.arrow.down.fill", title: L10n.Common.save)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(Color.cosmicBlue)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onExportTIFF) {
                actionLabel(symbol: "square.and.arrow.up", title: L10n.Library.exportTIFF)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .stroke(Color.starWhite.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionLabel(symbol: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.stakkaCaption)
        .fontWeight(.semibold)
        .foregroundStyle(Color.starWhite)
    }

    // MARK: - Helpers

    private var referenceFrameName: String? {
        guard let id = project.referenceFrameID else { return nil }
        return project.frame(id: id)?.name
    }
}
