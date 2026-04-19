import SwiftUI

struct StackedResultCard: View {
    let result: StackingResult
    let onSave: () -> Void
    let onExportTIFF: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.cosmicBlue)
                    .breathingGlow(color: .cosmicBlue, radius: 4)

                Text(L10n.Library.resultCompleted)
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)

                Spacer()

                Text(result.mode.title)
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.cosmicBlue)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .background(Color.cosmicBlue.opacity(0.12))
                    .continuousCorners(CornerRadius.md)
            }

            Image(uiImage: result.image)
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

            HStack(spacing: Spacing.sm) {
                metricBadge(symbol: "photo", value: "\(result.frameCount)")
                metricBadge(symbol: "scope", value: result.recap.referenceFrameName)
                metricBadge(symbol: "moon.fill", value: "\(result.recap.darkFrameCount)")
                metricBadge(symbol: "circle.lefthalf.filled", value: "\(result.recap.flatFrameCount)")
                if let cometMode = result.recap.cometMode {
                    metricBadge(symbol: cometMode.symbolName, value: cometMode.title)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.sm) {
                Button(action: onSave) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text(L10n.Common.save)
                    }
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cosmicBlue)

                Button(action: onExportTIFF) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(L10n.Library.exportTIFF)
                    }
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                }
                .buttonStyle(.bordered)
                .tint(.starWhite)
            }
        }
        .padding(Spacing.md)
        .glassCard()
    }

    private func metricBadge(symbol: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(value)
                .monospacedDigit()
        }
        .font(.stakkaSmall)
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(Color.spaceSurface.opacity(0.55))
        .continuousCorners(CornerRadius.md)
    }
}
