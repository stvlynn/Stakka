import SwiftUI

struct CameraControlsView: View {
    @ObservedObject var viewModel: CameraViewModel

    @State private var isMenuExpanded = false

    var body: some View {
        ZStack {
            VStack(spacing: Spacing.sm) {
                Spacer()

                if viewModel.isCapturing {
                    captureProgressView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                AstroModeSelectorView(
                    selectedMode: viewModel.astroMode,
                    isCapturing: viewModel.isCapturing,
                    onSelect: viewModel.applyAstroMode
                )

                AdvancedControlsMenu(viewModel: viewModel, isExpanded: $isMenuExpanded)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.lg)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)

            if viewModel.showExposurePicker {
                WheelPickerOverlay(
                    title: L10n.Camera.exposureTime,
                    items: exposureOptions,
                    selectedItem: viewModel.exposureTime,
                    displayText: { L10nFormat.seconds($0) },
                    onSelect: { viewModel.updateExposureTime($0) },
                    onDismiss: { viewModel.showExposurePicker = false }
                )
            }

            if viewModel.showShotsPicker {
                WheelPickerOverlay(
                    title: L10n.Camera.shotCountPicker,
                    items: shotsOptions,
                    selectedItem: viewModel.numberOfShots,
                    displayText: { "\($0)" },
                    onSelect: { viewModel.numberOfShots = $0 },
                    onDismiss: { viewModel.showShotsPicker = false }
                )
            }

            if viewModel.showAperturePicker {
                WheelPickerOverlay(
                    title: L10n.Camera.aperture,
                    items: apertureOptions,
                    selectedItem: viewModel.aperture,
                    displayText: { $0 },
                    onSelect: { viewModel.aperture = $0 },
                    onDismiss: { viewModel.showAperturePicker = false }
                )
            }

            if viewModel.showShutterPicker {
                WheelPickerOverlay(
                    title: L10n.Camera.shutterSpeed,
                    items: shutterOptions,
                    selectedItem: viewModel.shutterSpeed,
                    displayText: { $0 },
                    onSelect: { viewModel.updateShutterSpeed($0) },
                    onDismiss: { viewModel.showShutterPicker = false }
                )
            }

            if viewModel.showZoomPicker {
                WheelPickerOverlay(
                    title: L10n.Camera.zoomFactor,
                    items: zoomOptions,
                    selectedItem: viewModel.zoomLevel,
                    displayText: { $0 },
                    onSelect: { viewModel.zoomLevel = $0 },
                    onDismiss: { viewModel.showZoomPicker = false }
                )
            }

            if viewModel.showModePicker {
                WheelPickerOverlay(
                    title: L10n.Camera.shootingMode,
                    items: modeOptions,
                    selectedItem: viewModel.shootingMode,
                    displayText: { $0 },
                    onSelect: { viewModel.shootingMode = $0 },
                    onDismiss: { viewModel.showModePicker = false }
                )
            }
        }
    }

    private var captureProgressView: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView(value: viewModel.captureProgress)
                .tint(.cosmicBlue)
                .breathingGlow(color: .cosmicBlue, radius: 4)

            Text(L10nFormat.ratio(Int(viewModel.captureProgress * Double(viewModel.numberOfShots)), viewModel.numberOfShots))
                .font(.stakkaCaption)
                .foregroundStyle(Color.textSecondary)
                .monospacedDigit()
        }
        .padding(Spacing.lg)
        .glassCard()
    }

    private let exposureOptions: [Double] = {
        var options: [Double] = []
        for i in 1...10 { options.append(Double(i) * 0.1) }
        for i in 1...30 { options.append(Double(i)) }
        return options
    }()

    private let shotsOptions: [Int] = Array(2...100)

    private let apertureOptions = ["f/1.4", "f/1.8", "f/2.0", "f/2.8", "f/4.0", "f/5.6", "f/8.0", "f/11", "f/16", "f/22"]

    private let shutterOptions = ["1/8000", "1/4000", "1/2000", "1/1000", "1/500", "1/250", "1/125", "1/60", "1/30", "1/15", "1/8", "1/4", "1/2", "1\"", "2\"", "4\"", "8\"", "15\"", "20\"", "30\""]

    private let zoomOptions = ["0.5×", "1×", "2×", "3×", "5×", "10×"]

    private let modeOptions = ShootingMode.allCases.map(\.rawValue)
}

private struct AstroModeSelectorView: View {
    let selectedMode: AstroCaptureMode
    let isCapturing: Bool
    let onSelect: (AstroCaptureMode) -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            selectorTitle

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: Spacing.md) {
                        ForEach(AstroCaptureMode.allCases) { mode in
                            AstroModeCardView(
                                mode: mode,
                                isSelected: selectedMode == mode,
                                isDisabled: isCapturing
                            ) {
                                withAnimation(AnimationPreset.springBouncy) {
                                    onSelect(mode)
                                }
                            }
                            .id(mode.id)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.xs)
                }
                .onAppear {
                    proxy.scrollTo(selectedMode.id, anchor: .center)
                }
                .onChange(of: selectedMode) { _, newValue in
                    withAnimation(AnimationPreset.springBouncy) {
                        proxy.scrollTo(newValue.id, anchor: .center)
                    }
                }
            }
            .frame(height: 130)
        }
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.86))
        .continuousCorners(CornerRadius.xxl)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xxl, style: .continuous)
                .stroke(Color.starWhite.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Camera.modeSelector)
    }

    private var selectorTitle: some View {
        HStack {
            Spacer()

            Text(L10n.Camera.modeSelector)
                .font(.stakkaBodyMono)
                .foregroundStyle(Color.starWhite)
                .padding(.horizontal, Spacing.xl)
                .frame(height: 40)
                .background(Color.spaceSurface.opacity(0.58))
                .continuousCorners(CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                        .stroke(Color.starWhite.opacity(0.7), lineWidth: 1.4)
                )

            Spacer()
        }
    }
}

private struct AstroModeCardView: View {
    let mode: AstroCaptureMode
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: isSelected ? 24 : 18, weight: .bold))
                        .foregroundStyle(mode.cardForeground)
                        .accessibilityHidden(true)

                    Spacer()

                    if isSelected {
                        Circle()
                            .fill(mode.cardForeground)
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer(minLength: 0)

                Text(mode.localizedTitle)
                    .font(isSelected ? .stakkaHeadline : .stakkaCaption)
                    .foregroundStyle(mode.cardForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(mode.presetCode)
                    .font(.system(size: isSelected ? 26 : 20, weight: .bold, design: .rounded))
                    .foregroundStyle(mode.cardForeground.opacity(0.92))
                    .monospacedDigit()

                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(mode.cardForeground.opacity(index < mode.intensityDots ? 0.95 : 0.22))
                            .frame(width: 10, height: 7)
                    }
                }
            }
            .padding(Spacing.sm)
            .frame(width: isSelected ? 104 : 82, height: isSelected ? 122 : 100)
            .background(
                LinearGradient(
                    colors: [
                        mode.accent,
                        mode.secondaryAccent.opacity(mode == .moon ? 0.86 : 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .continuousCorners(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.starWhite.opacity(0.85) : Color.starWhite.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? mode.accent.opacity(0.38) : .clear, radius: 10, y: 4)
            .opacity(isSelected ? 1 : 0.42)
            .scaleEffect(isSelected ? 1 : 0.94)
            .animation(AnimationPreset.spring, value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(L10n.Accessibility.selectAstroMode(mode.localizedTitle))
        .accessibilityValue(mode.localizedHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension AstroCaptureMode {
    var cardForeground: Color {
        switch self {
        case .moon, .starTrails:
            return .spaceBackground
        case .milkyWay, .meteor:
            return .starWhite
        }
    }

    var intensityDots: Int {
        switch self {
        case .milkyWay: return 4
        case .starTrails: return 5
        case .moon: return 2
        case .meteor: return 3
        }
    }
}
