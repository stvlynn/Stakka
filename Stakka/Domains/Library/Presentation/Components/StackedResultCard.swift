import SwiftUI

struct StackedResultCard: View {
    let image: UIImage
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.cosmicBlue)
                    .breathingGlow(color: .cosmicBlue, radius: 4)

                Text("堆栈完成")
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)

                Spacer()
            }

            Image(uiImage: image)
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

            Button(action: onSave) {
                HStack {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("保存")
                }
                .font(.stakkaCaption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cosmicBlue)
        }
        .padding(Spacing.md)
        .glassCard()
    }
}
