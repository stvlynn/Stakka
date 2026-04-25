import SwiftUI

struct CometReviewStatusCard: View {
    let mode: CometStackingMode
    let reviewedCount: Int
    let totalCount: Int
    let needsReviewCount: Int
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(mode.title, systemImage: mode.symbolName)
                        .font(.stakkaHeadline)
                        .foregroundStyle(Color.starWhite)

                    Text(mode.description)
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Text("\(reviewedCount)/\(max(totalCount, 1))")
                    .font(.stakkaCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.nebulaPurple)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 6)
                    .liquidGlassPill(tint: .nebulaPurple)
                    .monospacedDigit()
            }

            HStack(spacing: Spacing.sm) {
                statusBadge(symbol: "sparkles", value: "\(totalCount)")
                statusBadge(symbol: "checkmark.circle.fill", value: "\(reviewedCount)")
                statusBadge(symbol: "exclamationmark.triangle.fill", value: "\(needsReviewCount)")
            }

            Button(action: onReview) {
                HStack {
                    Image(systemName: "viewfinder.circle.fill")
                    Text(L10n.Library.cometReviewAction(needsReviewCount: needsReviewCount))
                }
                .font(.stakkaCaption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
            }
            .buttonStyle(.glassProminent)
            .tint(.nebulaPurple)
        }
        .padding(Spacing.md)
        .glassCard()
    }

    private func statusBadge(symbol: String, value: String) -> some View {
        HStack(spacing: 6) {
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
