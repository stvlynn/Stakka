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
            .navigationTitle(L10n.Camera.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if cameraAuthorization == .authorized {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.showSettings.toggle()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(Color.starWhite)
                        }
                        .accessibilityLabel(L10n.Accessibility.openSettings)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                CameraSettingsView(viewModel: viewModel)
            }
        }
    }

    private var authorizedContent: some View {
        ZStack {
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.3), .clear, .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack {
                CameraHUDView(
                    aperture: viewModel.aperture,
                    shutterSpeed: viewModel.shutterSpeed,
                    iso: "ISO Auto",
                    zoom: viewModel.zoomLevel
                )
                .padding(.top, Spacing.sm)
                .padding(.horizontal, Spacing.md)

                Spacer()

                if let recentProjectTitle = viewModel.recentProjectTitle, !viewModel.isCapturing {
                    captureProjectCard(title: recentProjectTitle)
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                CameraControlsView(viewModel: viewModel)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.lg)
                    // Cap Dynamic Type so the capsule control row never
                    // breaks at AX sizes.
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            }
        }
        .task {
            viewModel.setupCamera()
        }
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
