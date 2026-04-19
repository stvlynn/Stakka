import SwiftUI

struct StackProjectSummaryCard: View {
    let project: StackingProject

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(project.title)
                        .font(.stakkaHeadline)
                        .foregroundStyle(Color.starWhite)

                    if let cometMode = project.cometMode {
                        HStack(spacing: 6) {
                            Image(systemName: cometMode.symbolName)
                            Text(cometMode.description)
                                .lineLimit(1)
                        }
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.nebulaPurple)
                    }

                    if let referenceFrameName {
                        HStack(spacing: 6) {
                            Image(systemName: "scope")
                            Text(referenceFrameName)
                                .lineLimit(1)
                        }
                        .font(.stakkaSmall)
                        .foregroundStyle(Color.textSecondary)
                    } else if project.cometMode == nil {
                        Text(L10n.Library.autoReferenceHint(lightTitle: StackFrameKind.light.title))
                            .font(.stakkaSmall)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.cosmicBlue)
                    .glow(color: .cosmicBlue, radius: 6)
            }

            HStack(spacing: Spacing.sm) {
                ForEach(StackFrameKind.allCases) { kind in
                    VStack(spacing: 6) {
                        Image(systemName: kind.symbolName)
                            .foregroundStyle(Color.cosmicBlue)
                        Text("\(project.frames(of: kind).filter(\.isEnabled).count)")
                            .font(.stakkaCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.starWhite)
                            .monospacedDigit()
                        Text(kind.shortLabel)
                            .font(.stakkaSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.spaceSurface.opacity(0.55))
                    .continuousCorners(CornerRadius.md)
                }
            }
        }
        .padding(Spacing.md)
        .glassCard()
    }

    private var referenceFrameName: String? {
        guard let referenceFrameID = project.referenceFrameID else { return nil }
        return project.frame(id: referenceFrameID)?.name
    }
}
