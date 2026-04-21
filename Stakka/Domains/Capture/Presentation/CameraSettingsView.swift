import SwiftUI

struct CameraSettingsView: View {
    @ObservedObject var viewModel: CameraViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        exposureSection
                        stackingSection
                        summarySection
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle(L10n.Camera.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                        .foregroundStyle(Color.cosmicBlue)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var exposureSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label(L10n.Camera.exposureSection, systemImage: "timer")
                .font(.stakkaHeadline)
                .foregroundStyle(Color.starWhite)

            stepRow(
                valueText: L10nFormat.seconds(viewModel.exposureTime),
                decrement: { viewModel.updateExposure(by: -0.1) },
                increment: { viewModel.updateExposure(by: 0.1) }
            )
            .padding(Spacing.md)
            .background(Color.spaceSurfaceElevated.opacity(0.6))
            .continuousCorners(CornerRadius.md)
        }
    }

    private var stackingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label(L10n.Camera.stackingSection, systemImage: "square.stack.3d.up.fill")
                .font(.stakkaHeadline)
                .foregroundStyle(Color.starWhite)

            VStack(spacing: Spacing.md) {
                HStack {
                    Text(L10n.Camera.shotCount)
                        .font(.stakkaBody)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    stepperControls(
                        valueText: "\(viewModel.numberOfShots)",
                        decrement: { viewModel.updateShotCount(by: -1) },
                        increment: { viewModel.updateShotCount(by: 1) }
                    )
                }

                Divider().overlay(Color.spaceSurfaceElevated)

                HStack {
                    Text(L10n.Camera.interval)
                        .font(.stakkaBody)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(L10nFormat.seconds(viewModel.intervalBetweenShots))
                        .font(.stakkaCaption)
                        .foregroundStyle(Color.cosmicBlue)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }

                stepRow(
                    valueText: L10nFormat.seconds(viewModel.intervalBetweenShots),
                    decrement: { viewModel.updateInterval(by: -0.1) },
                    increment: { viewModel.updateInterval(by: 0.1) }
                )
            }
            .padding(Spacing.md)
            .background(Color.spaceSurfaceElevated.opacity(0.6))
            .continuousCorners(CornerRadius.md)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label(L10n.Camera.summarySection, systemImage: "info.circle.fill")
                .font(.stakkaHeadline)
                .foregroundStyle(Color.starWhite)

            let totalTime = viewModel.exposureTime * Double(viewModel.numberOfShots) + viewModel.intervalBetweenShots * Double(viewModel.numberOfShots - 1)

            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                    Text(L10nFormat.duration(totalTime))
                        .font(.stakkaTitle)
                        .foregroundStyle(Color.cosmicBlue)
                        .monospacedDigit()
                        .breathingGlow(color: .cosmicBlue, radius: 4)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                    Text("\(viewModel.numberOfShots)")
                        .font(.stakkaTitle)
                        .foregroundStyle(Color.nebulaPurple)
                        .monospacedDigit()
                        .breathingGlow(color: .nebulaPurple, radius: 4)
                }
            }
            .padding(Spacing.md)
            .background(
                LinearGradient(
                    colors: [Color.cosmicBlue.opacity(0.1), Color.nebulaPurple.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .continuousCorners(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(Color.cosmicBlue.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func stepRow(valueText: String, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
        HStack {
            stepperControls(valueText: valueText, decrement: decrement, increment: increment)
            Spacer()
        }
    }

    private func stepperControls(
        valueText: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Button(action: decrement) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.textTertiary)
                    .font(.title3)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(valueText)
                .font(.stakkaCaption)
                .foregroundStyle(Color.cosmicBlue)
                .fontWeight(.semibold)
                .monospacedDigit()
                .frame(minWidth: 52)

            Button(action: increment) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.cosmicBlue)
                    .font(.title3)
                    .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
