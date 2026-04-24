import SwiftUI

struct CameraSettingsPanelView: View {
    @ObservedObject var viewModel: CameraViewModel
    let onClose: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(Color.starWhite.opacity(0.08))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    presetSection
                    readoutGrid
                    intervalStepper
                }
                .padding(Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 430)
        .background(Color.black.opacity(0.88))
        .continuousCorners(CornerRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(Color.starWhite.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Text(L10n.Camera.settingsTitle)
                .font(.stakkaBodyMono)
                .foregroundStyle(Color.starWhite)

            Spacer()

            Button(action: onClose) {
                Text(L10n.Common.close)
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(L10n.Camera.presetSection)
                .font(.stakkaCaption)
                .foregroundStyle(Color.textSecondary)

            VStack(spacing: Spacing.sm) {
                ForEach(AstroCaptureMode.allCases) { mode in
                    Button {
                        withAnimation(AnimationPreset.springBouncy) {
                            viewModel.applyAstroMode(mode)
                        }
                    } label: {
                        modeRow(mode)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Accessibility.selectAstroMode(mode.localizedTitle))
                    .accessibilityAddTraits(viewModel.astroMode == mode ? .isSelected : [])
                }
            }
        }
    }

    private func modeRow(_ mode: AstroCaptureMode) -> some View {
        let isSelected = viewModel.astroMode == mode

        return HStack(spacing: Spacing.md) {
            Image(systemName: mode.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSelected ? Color.spaceBackground : mode.accent)
                .frame(width: 34, height: 34)
                .background(isSelected ? mode.accent : mode.accent.opacity(0.14))
                .continuousCorners(CornerRadius.sm)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.localizedTitle)
                    .font(.stakkaCaption)
                    .foregroundStyle(Color.starWhite)
                Text(mode.localizedHint)
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(mode.presetCode)
                .font(.stakkaNumericSmall)
                .foregroundStyle(isSelected ? mode.accent : Color.textTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(isSelected ? mode.accent.opacity(0.16) : Color.spaceSurface.opacity(0.42))
        .continuousCorners(CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .stroke(isSelected ? mode.accent.opacity(0.7) : Color.clear, lineWidth: 1)
        )
    }

    private var readoutGrid: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            CameraSettingsReadout(
                icon: "timer",
                title: L10n.Camera.exposureSection,
                value: L10nFormat.exposure(viewModel.exposureTime),
                tint: .cosmicBlue
            )
            CameraSettingsReadout(
                icon: "photo.stack",
                title: L10n.Camera.shotCount,
                value: "\(viewModel.numberOfShots)",
                tint: .nebulaPurple
            )
            CameraSettingsReadout(
                icon: "clock.arrow.circlepath",
                title: L10n.Camera.interval,
                value: L10nFormat.seconds(viewModel.intervalBetweenShots),
                tint: .meteorTeal
            )
            CameraSettingsReadout(
                icon: "plus.magnifyingglass",
                title: L10n.Camera.zoom,
                value: viewModel.zoomLevel,
                tint: .moonGold
            )
        }
    }

    private var intervalStepper: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.meteorTeal)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Camera.interval)
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.textTertiary)
                Text(L10nFormat.seconds(viewModel.intervalBetweenShots))
                    .font(.stakkaNumeric)
                    .foregroundStyle(Color.starWhite)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: Spacing.sm) {
                Button {
                    viewModel.updateInterval(by: -0.1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.updateInterval(by: 0.1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.meteorTeal)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(Color.spaceSurface.opacity(0.46))
        .continuousCorners(CornerRadius.md)
    }
}

private struct CameraSettingsReadout: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(value)
                .font(.stakkaNumeric)
                .foregroundStyle(Color.starWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .monospacedDigit()

            Text(title)
                .font(.stakkaSmall)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.spaceSurface.opacity(0.46))
        .continuousCorners(CornerRadius.md)
        .accessibilityElement(children: .combine)
    }
}
