import SwiftUI

// MARK: - Advanced Controls Menu
struct AdvancedControlsMenu: View {
    @ObservedObject var viewModel: CameraViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: Spacing.md) {
            dragIndicator

            if isExpanded {
                advancedControls
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            mainControls
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xxl, style: .continuous)
                .fill(Color.spaceSurface.opacity(0.97))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xxl, style: .continuous)
                        .stroke(Color.starWhite.opacity(0.12), lineWidth: 1)
                )
        )
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xxl, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: -4)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -50 {
                        withAnimation(AnimationPreset.springBouncy) {
                            isExpanded = true
                        }
                    } else if value.translation.height > 50 {
                        withAnimation(AnimationPreset.springBouncy) {
                            isExpanded = false
                        }
                    }
                }
        )
    }

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.textTertiary.opacity(0.6))
            .frame(width: 40, height: 5)
            .padding(.bottom, Spacing.xs)
    }

    private var advancedControls: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                advancedControlButton(
                    icon: "camera.aperture",
                    label: L10n.Camera.aperture,
                    value: viewModel.aperture
                ) {
                    viewModel.showAperturePicker = true
                }

                advancedControlButton(
                    icon: "timer",
                    label: L10n.Camera.shutter,
                    value: viewModel.shutterSpeed
                ) {
                    viewModel.showShutterPicker = true
                }
            }

            HStack(spacing: Spacing.sm) {
                advancedControlButton(
                    icon: "camera.metering.multispot",
                    label: L10n.Camera.zoom,
                    value: viewModel.zoomLevel
                ) {
                    viewModel.showZoomPicker = true
                }

                advancedControlButton(
                    icon: "dial.medium.fill",
                    label: L10n.Camera.mode,
                    value: viewModel.shootingMode
                ) {
                    viewModel.showModePicker = true
                }
            }

            Divider()
                .overlay(Color.spaceSurfaceElevated)
                .padding(.vertical, Spacing.xs)
        }
    }

    private var mainControls: some View {
        HStack(spacing: Spacing.xl) {
            controlButton(
                icon: "timer",
                value: L10nFormat.decimal(viewModel.exposureTime, digits: 1),
                isActive: viewModel.showExposurePicker
            ) {
                withAnimation(AnimationPreset.springBouncy) {
                    viewModel.showExposurePicker.toggle()
                }
            }

            captureButton

            controlButton(
                icon: "photo.stack",
                value: "\(viewModel.numberOfShots)",
                isActive: viewModel.showShotsPicker
            ) {
                withAnimation(AnimationPreset.springBouncy) {
                    viewModel.showShotsPicker.toggle()
                }
            }
        }
    }

    private func controlButton(icon: String, value: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Text(value)
                    .font(.stakkaNumericLarge)
                    .foregroundStyle(isActive ? Color.cosmicBlue : Color.starWhite)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isActive ? Color.cosmicBlue : Color.textTertiary)
            }
            .frame(width: 70, height: Spacing.touchTarget)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                    .fill(isActive ? Color.cosmicBlue.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(AnimationPreset.spring, value: isActive)
        }
    }

    private func advancedControlButton(icon: String, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.cosmicBlue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.textTertiary)
                    Text(value)
                        .font(.stakkaNumericSmall)
                        .foregroundStyle(Color.starWhite)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget)
            .background(Color.spaceSurfaceElevated.opacity(0.5))
            .continuousCorners(CornerRadius.md)
        }
        .buttonStyle(.plain)
    }

    private var captureButton: some View {
        Button {
            withAnimation(AnimationPreset.springBouncy) {
                if viewModel.isCapturing {
                    viewModel.stopStackingCapture()
                } else {
                    viewModel.startStackingCapture()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(viewModel.isCapturing ? Color.galaxyPink : Color.cosmicBlue, lineWidth: 3.5)
                    .frame(width: 76, height: 76)
                    .glow(color: viewModel.isCapturing ? .galaxyPink : .cosmicBlue, radius: 10)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: viewModel.isCapturing
                                ? [Color.galaxyPink, Color.galaxyPink.opacity(0.8)]
                                : [Color.cosmicBlue, Color.cosmicBlue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                if viewModel.isCapturing {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.starWhite)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.starWhite)
                }
            }
        }
        .scaleEffect(viewModel.isCapturing ? 0.92 : 1.0)
        .animation(AnimationPreset.springBouncy, value: viewModel.isCapturing)
        .sensoryFeedback(.selection, trigger: viewModel.isCapturing)
        .accessibilityLabel(viewModel.isCapturing ? L10n.Accessibility.stopCapture : L10n.Accessibility.startCapture)
    }
}
