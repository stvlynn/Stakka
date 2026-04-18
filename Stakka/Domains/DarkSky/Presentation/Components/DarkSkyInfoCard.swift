import SwiftUI

struct DarkSkyInfoCard: View {
    let reading: LightPollution

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.cosmicBlue)
                    .font(.title3)
                    .breathingGlow(color: .cosmicBlue, radius: 4)

                Text("光污染等级")
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)

                Spacer()

                Circle()
                    .fill(reading.bortleLevel.color)
                    .frame(width: 12, height: 12)
                    .glow(color: reading.bortleLevel.color, radius: 4)
            }

            Divider().overlay(Color.spaceSurfaceElevated)

            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)

                    Text("\(reading.coordinate.latitude, specifier: "%.4f")°")
                        .font(.stakkaCaption)
                        .foregroundStyle(Color.textSecondary)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)

                    Text("\(reading.coordinate.longitude, specifier: "%.4f")°")
                        .font(.stakkaCaption)
                        .foregroundStyle(Color.textSecondary)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }

            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(reading.bortleLevel.color)

                Text(reading.bortleLevel.title)
                    .font(.stakkaCaption)
                    .foregroundStyle(reading.bortleLevel.color)
                    .fontWeight(.semibold)
            }
        }
        .padding(Spacing.md)
        .glassCard()
    }
}
