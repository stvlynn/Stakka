import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()

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
            .onAppear {
                viewModel.setupCamera()
            }
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
