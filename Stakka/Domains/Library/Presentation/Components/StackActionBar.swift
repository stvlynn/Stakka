import SwiftUI

/// Sticky bottom bar for the redesigned project detail view. Collapses the
/// old analyze / register / stack trio into a single dominant CTA and
/// surfaces in-progress / error state as slim toasts above the button so
/// they never clip under the safe area.
struct StackActionBar: View {
    let phase: LibraryStackingViewModel.ProcessingPhase
    let errorMessage: String?
    let progress: PipelineProgress?
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: Spacing.sm) {
            VStack(spacing: Spacing.sm) {
                if let errorMessage {
                    toast(
                        symbol: "exclamationmark.triangle.fill",
                        tint: .galaxyPink,
                        message: errorMessage
                    )
                }

                if let progress, phase != .idle {
                    progressPanel(progress)
                } else if phase != .idle {
                    // Fallback: we know we're working, but no progress data yet
                    // (usually the first tick before the processor reports).
                    toast(
                        symbol: phase.symbolName,
                        tint: .appAccent,
                        message: phase.title,
                        showsSpinner: true
                    )
                }

                primaryButton
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        .background {
            Rectangle()
                .fill(Color.liquidGlassSurface)
                .glassEffect(.regular, in: Rectangle())
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.starWhite.opacity(0.08))
                .frame(height: 1)
        }
        .animation(AnimationPreset.smooth, value: progress)
        .animation(AnimationPreset.smooth, value: errorMessage)
    }

    // MARK: - Primary CTA

    private var primaryButton: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                Text(L10n.Library.startStacking)
            }
            .font(.stakkaCaption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.starWhite)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Spacing.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.glassProminent)
        .tint(isEnabled ? Color.appAccent : Color.textMuted)
        .disabled(!isEnabled)
        .accessibilityLabel(L10n.Library.startStacking)
        .accessibilityIdentifier("library.startStacking")
    }

    // MARK: - Progress panel

    /// Displays the current stage title, a thin progress bar, frame counter,
    /// throughput (frames/s), and rough ETA. All three secondary figures
    /// are derived from the `PipelineProgress` snapshot in the ViewModel —
    /// the view has no timers of its own.
    private func progressPanel(_ progress: PipelineProgress) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.appAccent)
                Text(stageTitle(progress.stage))
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.starWhite)
                Spacer()
                if progress.total > 0 {
                    Text(L10n.Library.progressCount(current: progress.completed, total: progress.total))
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.textSecondary)
                        .monospacedDigit()
                }
            }

            // Determinate bar when total is known, indeterminate tint stripe
            // otherwise.
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.starWhite.opacity(0.14))
                    .frame(height: 6)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.appAccent)
                        .frame(width: max(8, geo.size.width * progress.stageFraction), height: 6)
                }
                .frame(height: 6)
            }

            HStack(spacing: Spacing.sm) {
                if progress.framesPerSecond > 0 {
                    metricChip(
                        symbol: "speedometer",
                        text: L10n.Library.progressThroughput(fps: formatted(progress.framesPerSecond))
                    )
                }
                if let remaining = progress.estimatedRemaining {
                    metricChip(
                        symbol: "clock",
                        text: L10n.Library.progressEta(seconds: Int(remaining.rounded()))
                    )
                }
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .liquidGlassCard(cornerRadius: CornerRadius.md, tint: .appAccent)
    }

    private func stageTitle(_ stage: StackingProgressStage) -> String {
        switch stage {
        case .analyzing: return L10n.Library.progressAnalyzing
        case .registering: return L10n.Library.progressRegistering
        case .stacking: return L10n.Library.progressStacking
        }
    }

    private func metricChip(symbol: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(text).monospacedDigit()
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 2)
        .liquidGlassPill()
    }

    private func formatted(_ value: Double) -> String {
        // 1 decimal place is enough; drops to 0 for very slow cases.
        if value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    // MARK: - Toast

    private func toast(
        symbol: String,
        tint: Color,
        message: String,
        showsSpinner: Bool = false
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            if showsSpinner {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            } else {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
            }
            Text(message)
                .font(.stakkaSmall)
                .foregroundStyle(Color.starWhite)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .liquidGlassCard(cornerRadius: CornerRadius.md, tint: tint)
    }
}
