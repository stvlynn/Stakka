import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @State private var cameraAuthorization: AVAuthorizationStatus
        = AVCaptureDevice.authorizationStatus(for: .video)

    init(viewModel: CameraViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                switch cameraAuthorization {
                case .authorized:
                    authorizedContent
                case .notDetermined:
                    PermissionPrimerView(
                        kind: .camera,
                        isDenied: false,
                        onAuthorize: requestCameraAccess
                    )
                case .denied, .restricted:
                    PermissionPrimerView(
                        kind: .camera,
                        isDenied: true,
                        onAuthorize: requestCameraAccess
                    )
                @unknown default:
                    PermissionPrimerView(
                        kind: .camera,
                        isDenied: true,
                        onAuthorize: requestCameraAccess
                    )
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }

    private var authorizedContent: some View {
        ZStack {
            Color.spaceBackground
                .ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                CameraTopBarView(
                    mode: viewModel.astroMode,
                    isCapturing: viewModel.isCapturing,
                    isSettingsPresented: viewModel.showSettings
                ) {
                    withAnimation(AnimationPreset.springBouncy) {
                        viewModel.showSettings.toggle()
                    }
                }
                .padding(.top, Spacing.sm)

                previewStage

                Spacer(minLength: 318)
            }
            .padding(.horizontal, Spacing.md)

            CameraControlsView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            viewModel.setupCamera()
        }
    }

    private var previewStage: some View {
        ZStack(alignment: .top) {
            CameraPreviewView(session: viewModel.captureSession)
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.45), .clear, .black.opacity(0.56)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .continuousCorners(CornerRadius.xl)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                        .stroke(Color.starWhite.opacity(0.14), lineWidth: 1)
                )

            VStack(spacing: Spacing.sm) {
                CameraHUDView(
                    aperture: viewModel.aperture,
                    shutterSpeed: viewModel.shutterSpeed,
                    iso: "ISO Auto",
                    zoom: viewModel.zoomLevel
                )
                .padding(.top, Spacing.md)
                .padding(.horizontal, Spacing.md)

                Spacer()

                if let liveStackedImage = viewModel.liveStackedImage,
                   viewModel.isCapturing || viewModel.liveStackedFrameCount > 1 {
                    liveStackCard(image: liveStackedImage)
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let recentProjectTitle = viewModel.recentProjectTitle, !viewModel.isCapturing {
                    captureProjectCard(title: recentProjectTitle)
                        .padding(.bottom, Spacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if viewModel.showSettings {
                CameraSettingsPanelView(viewModel: viewModel) {
                    withAnimation(AnimationPreset.springBouncy) {
                        viewModel.showSettings = false
                    }
                }
                .padding(Spacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }

    private func requestCameraAccess() {
        if cameraAuthorization == .denied || cameraAuthorization == .restricted {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
            return
        }
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                cameraAuthorization = granted ? .authorized : .denied
            }
        }
    }

    private func captureProjectCard(title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .foregroundStyle(Color.cosmicBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Camera.recentProjectSaved)
                    .font(.stakkaCaption)
                    .foregroundStyle(Color.starWhite)
                Text(title)
                    .font(.stakkaSmall)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .glassCard()
    }

    private func liveStackCard(image: UIImage) -> some View {
        HStack(spacing: Spacing.md) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 74, height: 56)
                .continuousCorners(CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .stroke(Color.starWhite.opacity(0.16), lineWidth: 1)
                )

            HStack(spacing: Spacing.lg) {
                metric(systemImage: "sparkles", value: "\(viewModel.liveStackedFrameCount)")
                metric(systemImage: "clock", value: L10nFormat.duration(viewModel.liveStackedExposure))

                if viewModel.liveRejectedFrameCount > 0 {
                    metric(systemImage: "exclamationmark.triangle.fill", value: "\(viewModel.liveRejectedFrameCount)")
                        .foregroundStyle(Color.galaxyPink)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .background(Color.black.opacity(0.74))
        .continuousCorners(CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                .stroke(Color.starWhite.opacity(0.1), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func metric(systemImage: String, value: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textTertiary)
            Text(value)
                .font(.stakkaNumericSmall)
                .foregroundStyle(Color.starWhite)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
    }
}

private struct CameraTopBarView: View {
    let mode: AstroCaptureMode
    let isCapturing: Bool
    let isSettingsPresented: Bool
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            proPill
                .frame(width: 96, alignment: .leading)

            Spacer(minLength: Spacing.sm)

            livePill
                .frame(maxWidth: 156)

            Spacer(minLength: Spacing.sm)

            settingsButton
                .frame(width: 96, alignment: .trailing)
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private var proPill: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(L10n.Camera.proBadge)
                .font(.stakkaCaption)
                .foregroundStyle(Color.spaceBackground)
                .padding(.horizontal, Spacing.md)
                .frame(height: 36)
                .background(Color.auroraGreen)
                .continuousCorners(18)
        }
        .padding(4)
        .frame(height: 44)
        .background(Color.black.opacity(0.82))
        .continuousCorners(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.starWhite.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel(L10n.Camera.proBadge)
    }

    private var livePill: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: mode.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)

            Circle()
                .fill(isCapturing ? Color.galaxyPink : Color.ctaAccent)
                .frame(width: 9, height: 9)
                .breathingGlow(color: isCapturing ? .galaxyPink : .ctaAccent, radius: 4)

            Text(mode.localizedTitle)
                .font(.stakkaNumericSmall)
                .foregroundStyle(Color.starWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.9))
        .continuousCorners(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.starWhite.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L10n.Camera.liveStatus), \(mode.localizedTitle)")
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isSettingsPresented ? Color.spaceBackground : Color.starWhite)
                .frame(width: 72, height: 44)
                .background(isSettingsPresented ? Color.auroraGreen : Color.spaceSurface.opacity(0.86))
                .continuousCorners(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.starWhite.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.42), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Accessibility.openSettings)
    }
}

extension AstroCaptureMode {
    var localizedTitle: String {
        switch self {
        case .milkyWay: return L10n.Camera.modeMilkyWay
        case .starTrails: return L10n.Camera.modeStarTrails
        case .moon: return L10n.Camera.modeMoon
        case .meteor: return L10n.Camera.modeMeteor
        }
    }

    var localizedHint: String {
        switch self {
        case .milkyWay: return L10n.Camera.modeMilkyWayHint
        case .starTrails: return L10n.Camera.modeStarTrailsHint
        case .moon: return L10n.Camera.modeMoonHint
        case .meteor: return L10n.Camera.modeMeteorHint
        }
    }

    var systemImage: String {
        switch self {
        case .milkyWay: return "sparkles"
        case .starTrails: return "circle.dotted"
        case .moon: return "moon.fill"
        case .meteor: return "bolt.fill"
        }
    }

    var accent: Color {
        switch self {
        case .milkyWay: return .cosmicBlue
        case .starTrails: return .trailAmber
        case .moon: return .moonGold
        case .meteor: return .meteorTeal
        }
    }

    var secondaryAccent: Color {
        switch self {
        case .milkyWay: return .nebulaPurple
        case .starTrails: return .galaxyPink
        case .moon: return .starWhite
        case .meteor: return .auroraGreen
        }
    }

    var presetCode: String {
        switch self {
        case .milkyWay: return "15s"
        case .starTrails: return "30s"
        case .moon: return "1/125"
        case .meteor: return "20s"
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
