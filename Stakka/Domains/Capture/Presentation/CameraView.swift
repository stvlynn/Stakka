import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel

    init(viewModel: CameraViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

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
                }
            }
            .navigationTitle("堆栈拍摄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.starWhite)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                CameraSettingsView(viewModel: viewModel)
            }
            .task {
                viewModel.setupCamera()
            }
        }
    }

    private func captureProjectCard(title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .foregroundStyle(Color.cosmicBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text("已写入最近工程")
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
