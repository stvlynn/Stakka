import SwiftUI

struct CameraControlsView: View {
    @ObservedObject var viewModel: CameraViewModel

    @State private var isMenuExpanded = false

    var body: some View {
        ZStack {
            if viewModel.isCapturing {
                captureProgressView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            VStack {
                Spacer()
                AdvancedControlsMenu(viewModel: viewModel, isExpanded: $isMenuExpanded)
            }

            if viewModel.showExposurePicker {
                WheelPickerOverlay(
                    title: L10n.Camera.exposureTime,
                    items: exposureOptions,
                    selectedItem: viewModel.exposureTime,
                    displayText: { L10nFormat.seconds($0) },
                    onSelect: { viewModel.exposureTime = $0 },
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
                    onSelect: { viewModel.shutterSpeed = $0 },
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
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, 200)
    }

    private let exposureOptions: [Double] = {
        var options: [Double] = []
        for i in 1...10 { options.append(Double(i) * 0.1) }
        for i in 1...30 { options.append(Double(i)) }
        return options
    }()

    private let shotsOptions: [Int] = Array(2...100)

    private let apertureOptions = ["f/1.4", "f/1.8", "f/2.0", "f/2.8", "f/4.0", "f/5.6", "f/8.0", "f/11", "f/16", "f/22"]

    private let shutterOptions = ["1/8000", "1/4000", "1/2000", "1/1000", "1/500", "1/250", "1/125", "1/60", "1/30", "1/15", "1/8", "1/4", "1/2", "1\"", "2\"", "4\"", "8\"", "15\"", "30\""]

    private let zoomOptions = ["0.5×", "1×", "2×", "3×", "5×", "10×"]

    private let modeOptions = ShootingMode.allCases.map(\.rawValue)
}
