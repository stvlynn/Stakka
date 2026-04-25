import SwiftUI

struct ProcessingStatusCard: View {
    let phase: LibraryStackingViewModel.ProcessingPhase

    var body: some View {
        HStack(spacing: Spacing.md) {
            ProgressView()
                .tint(.appAccent)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: phase.symbolName)
                    Text(phase.title)
                }
                .font(.stakkaCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.starWhite)

                Text(L10n.Library.processingUpdating)
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .glassCard()
    }
}
