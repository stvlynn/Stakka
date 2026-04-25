import SwiftUI

struct CameraSettingsPanelView: View {
    @ObservedObject var viewModel: CameraViewModel
    let onClose: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: Spacing.sm) {
            VStack(spacing: 0) {
                header

                Divider()
                    .overlay(Color.starWhite.opacity(0.08))

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        intervalStepper
                    }
                    .padding(Spacing.lg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 180)
            .systemGlassCard(cornerRadius: CornerRadius.lg)
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Text(L10n.Camera.settingsTitle)
                .font(.stakkaBodyMono)
                .foregroundStyle(Color.starWhite)

            Spacer()

            Button(action: onClose) {
                Text(L10n.Common.close)
                    .font(.stakkaCaption)
                    .foregroundStyle(Color.starWhite)
                    .frame(minWidth: Spacing.touchTarget, minHeight: Spacing.touchTarget)
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var intervalStepper: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appAccent)
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
                .buttonStyle(.glass)

                Button {
                    viewModel.updateInterval(by: 0.1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.appAccent)
                        .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                }
                .buttonStyle(.glass)
                .tint(Color.appAccent)
            }
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 58)
        .systemGlassCard(cornerRadius: CornerRadius.lg)
    }
}
