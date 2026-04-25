import SwiftUI

// MARK: - Advanced Controls Menu

/// Bottom-of-screen camera deck. Combines an inline horizontal wheel
/// (for the active capture parameter), a draggable expand/collapse
/// drawer, and the primary capture button with its progress ring.
struct AdvancedControlsMenu: View {
    @ObservedObject var viewModel: CameraViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: Spacing.sm) {
            inlineWheel

            menuCard
        }
    }

    // MARK: Inline wheel

    /// The horizontal wheel sits directly above the drawer. It only
    /// renders when the user has activated a control (avoiding extra
    /// chrome when the user is just framing a shot).
    @ViewBuilder
    private var inlineWheel: some View {
        if let active = viewModel.activeInlineControl {
            wheel(for: active)
                .padding(.horizontal, Spacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func wheel(for control: CameraInlineControl) -> some View {
        switch control {
        case .exposure:
            HorizontalWheelPicker(
                title: L10n.Camera.exposureTime,
                items: Self.exposureOptions,
                selection: viewModel.exposureTime,
                displayText: { L10nFormat.seconds($0) },
                valueText: { L10nFormat.exposure($0) },
                onSelect: { viewModel.updateExposureTime($0) },
                onDismiss: { viewModel.dismissInlineControl() }
            )
        case .shots:
            HorizontalWheelPicker(
                title: L10n.Camera.shotCountPicker,
                items: Self.shotsOptions,
                selection: viewModel.numberOfShots,
                displayText: { "\($0)" },
                valueText: { "\($0)" },
                onSelect: { viewModel.numberOfShots = $0 },
                onDismiss: { viewModel.dismissInlineControl() }
            )
        case .aperture:
            HorizontalWheelPicker(
                title: L10n.Camera.aperture,
                items: Self.apertureOptions,
                selection: viewModel.aperture,
                displayText: { $0 },
                valueText: { $0 },
                onSelect: { viewModel.aperture = $0 },
                onDismiss: { viewModel.dismissInlineControl() }
            )
        case .shutter:
            HorizontalWheelPicker(
                title: L10n.Camera.shutterSpeed,
                items: Self.shutterOptions,
                selection: viewModel.shutterSpeed,
                displayText: { $0 },
                valueText: { $0 },
                onSelect: { viewModel.updateShutterSpeed($0) },
                onDismiss: { viewModel.dismissInlineControl() }
            )
        case .zoom:
            HorizontalWheelPicker(
                title: L10n.Camera.zoomFactor,
                items: Self.zoomOptions,
                selection: viewModel.zoomLevel,
                displayText: { $0 },
                valueText: { $0 },
                onSelect: { viewModel.zoomLevel = $0 },
                onDismiss: { viewModel.dismissInlineControl() }
            )
        case .mode:
            HorizontalWheelPicker(
                title: L10n.Camera.shootingMode,
                items: Self.modeOptions,
                selection: viewModel.shootingMode,
                displayText: { $0 },
                valueText: { $0 },
                onSelect: { viewModel.shootingMode = $0 },
                onDismiss: { viewModel.dismissInlineControl() }
            )
        }
    }

    // MARK: Drawer card

    private var menuCard: some View {
        VStack(spacing: Spacing.md) {
            dragIndicator

            if isExpanded {
                advancedControls
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            mainControls
        }
        .padding(Spacing.lg)
        .liquidGlassCard(cornerRadius: CornerRadius.xxl)
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
                    value: viewModel.aperture,
                    isActive: viewModel.activeInlineControl == .aperture
                ) {
                    toggle(.aperture)
                }

                advancedControlButton(
                    icon: "timer",
                    label: L10n.Camera.shutter,
                    value: viewModel.shutterSpeed,
                    isActive: viewModel.activeInlineControl == .shutter
                ) {
                    toggle(.shutter)
                }
            }

            HStack(spacing: Spacing.sm) {
                advancedControlButton(
                    icon: "camera.metering.multispot",
                    label: L10n.Camera.zoom,
                    value: viewModel.zoomLevel,
                    isActive: viewModel.activeInlineControl == .zoom
                ) {
                    toggle(.zoom)
                }

                advancedControlButton(
                    icon: "dial.medium.fill",
                    label: L10n.Camera.mode,
                    value: viewModel.shootingMode,
                    isActive: viewModel.activeInlineControl == .mode
                ) {
                    toggle(.mode)
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
                value: L10nFormat.exposure(viewModel.exposureTime),
                isActive: viewModel.activeInlineControl == .exposure
            ) {
                toggle(.exposure)
            }

            CameraCaptureButton(viewModel: viewModel)

            controlButton(
                icon: "photo.stack",
                value: "\(viewModel.numberOfShots)",
                isActive: viewModel.activeInlineControl == .shots
            ) {
                toggle(.shots)
            }
        }
    }

    private func toggle(_ control: CameraInlineControl) {
        withAnimation(AnimationPreset.springBouncy) {
            viewModel.toggleInlineControl(control)
        }
    }

    // MARK: Buttons

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
            .liquidGlassCard(
                cornerRadius: CornerRadius.sm,
                tint: isActive ? Color.cosmicBlue : nil,
                isInteractive: true
            )
            .contentShape(Rectangle())
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(AnimationPreset.spring, value: isActive)
        }
        .buttonStyle(.plain)
    }

    private func advancedControlButton(
        icon: String,
        label: String,
        value: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isActive ? Color.cosmicBlue : Color.cosmicBlueDim)
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

                Image(systemName: isActive ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isActive ? Color.cosmicBlue : Color.textMuted)
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget)
            .liquidGlassCard(
                cornerRadius: CornerRadius.md,
                tint: isActive ? Color.cosmicBlue : nil,
                isInteractive: true
            )
            .animation(AnimationPreset.spring, value: isActive)
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Option sets

extension AdvancedControlsMenu {
    static let exposureOptions: [Double] = {
        var options: [Double] = []
        for i in 1...10 { options.append(Double(i) * 0.1) }
        for i in 1...30 { options.append(Double(i)) }
        return options
    }()

    static let shotsOptions: [Int] = Array(2...100)

    static let apertureOptions: [String] = [
        "f/1.4", "f/1.8", "f/2.0", "f/2.8", "f/4.0",
        "f/5.6", "f/8.0", "f/11", "f/16", "f/22"
    ]

    static let shutterOptions: [String] = [
        "1/8000", "1/4000", "1/2000", "1/1000", "1/500",
        "1/250", "1/125", "1/60", "1/30", "1/15",
        "1/8", "1/4", "1/2", "1\"", "2\"", "4\"", "8\"",
        "15\"", "20\"", "30\""
    ]

    static let zoomOptions: [String] = ["0.5×", "1×", "2×", "3×", "5×", "10×"]

    static let modeOptions: [String] = ShootingMode.allCases.map(\.rawValue)
}
