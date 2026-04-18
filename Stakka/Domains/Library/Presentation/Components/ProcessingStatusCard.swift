import SwiftUI

struct ProcessingStatusCard: View {
    let phase: LibraryStackingViewModel.ProcessingPhase

    var body: some View {
        HStack(spacing: Spacing.md) {
            ProgressView()
                .tint(.cosmicBlue)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: phase.symbolName)
                    Text(phase.title)
                }
                .font(.stakkaCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.starWhite)

                Text("工程正在更新")
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .glassCard()
    }
}
