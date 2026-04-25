import SwiftUI

struct DarkSkyInfoCard: View {
    let reading: LightPollution

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            Divider().overlay(Color.starWhite.opacity(0.10))
            coordinateRow
            Divider().overlay(Color.starWhite.opacity(0.10))
            metricsSection
            Divider().overlay(Color.starWhite.opacity(0.10))
            visibilitySection
        }
        .padding(Spacing.md)
        .glassCard()
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.appAccent)
                .font(.title3)
                .breathingGlow(color: .appAccent, radius: 4)

            Text(L10n.DarkSky.cardTitle)
                .font(.stakkaHeadline)
                .foregroundStyle(Color.starWhite)

            Spacer()

            Text("Bortle \(reading.bortleLevel.rawValue)")
                .font(.stakkaCaption)
                .foregroundStyle(reading.bortleLevel.color)
                .fontWeight(.semibold)

            Circle()
                .fill(reading.bortleLevel.color)
                .frame(width: 12, height: 12)
                .glow(color: reading.bortleLevel.color, radius: 4)
        }
    }

    private var coordinateRow: some View {
        HStack {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                Text(L10nFormat.coordinate(reading.coordinate.latitude))
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
            }

            HStack(spacing: Spacing.xs) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
                Text(L10nFormat.coordinate(reading.coordinate.longitude))
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: Spacing.xs) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(reading.bortleLevel.color)
                Text(reading.bortleLevel.title)
                    .font(.stakkaSmall)
                    .foregroundStyle(reading.bortleLevel.color)
                    .fontWeight(.semibold)
            }
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            dataRow(
                label: L10n.DarkSky.labelSQM,
                value: L10nFormat.sqm(reading.bortleLevel.sqmValue)
            )
            dataRow(
                label: L10n.DarkSky.labelDarkSkyGrade,
                value: reading.bortleLevel.darkSkyGradeTitle
            )
            dataRow(
                label: L10n.DarkSky.labelBrightness,
                value: L10nFormat.brightness(reading.bortleLevel.artificialBrightness)
            )
        }
    }

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            dataRow(
                label: L10n.DarkSky.labelMilkyWay,
                value: reading.bortleLevel.milkyWayVisibility
            )
            dataRow(
                label: L10n.DarkSky.labelGalaxy,
                value: reading.bortleLevel.galaxyVisibility
            )
            dataRow(
                label: L10n.DarkSky.labelZodiacal,
                value: reading.bortleLevel.zodiacalLightVisibility
            )
        }
    }

    private func dataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.stakkaSmall)
                .foregroundStyle(Color.textTertiary)
            Spacer()
            Text(value)
                .font(.stakkaSmall)
                .foregroundStyle(Color.textSecondary)
                .fontWeight(.medium)
        }
    }
}
