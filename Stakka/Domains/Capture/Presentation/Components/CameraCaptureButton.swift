import SwiftUI

/// The capture / stop button. Idle state shows the green CTA ring with a
/// sparkles glyph; capturing state replaces the inner glyph with a stop
/// square, switches the outer ring into a camera-accent progress arc, and
/// surfaces a tiny `current/total` caption inside the disc.
///
/// Used in two places:
/// - Inline at the center of `AdvancedControlsMenu` while idle.
/// - Floating over the fullscreen preview while capturing.
struct CameraCaptureButton: View {
    @ObservedObject var viewModel: CameraViewModel

    var body: some View {
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
                outerRing

                Circle()
                    .fill(Color.clear)
                    .frame(width: 64, height: 64)
                    .systemGlass(in: Circle(), tint: Color.appAccent, isInteractive: true)

                if viewModel.isCapturing {
                    captureCounter
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.starWhite)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(viewModel.isCapturing ? 0.92 : 1.0)
        .animation(AnimationPreset.springBouncy, value: viewModel.isCapturing)
        .sensoryFeedback(.selection, trigger: viewModel.isCapturing)
        .accessibilityLabel(viewModel.isCapturing ? L10n.Accessibility.stopCapture : L10n.Accessibility.startCapture)
        .accessibilityValue(
            viewModel.isCapturing
                ? L10nFormat.ratio(currentShotIndex, viewModel.numberOfShots)
                : ""
        )
    }

    private var outerRing: some View {
        ZStack {
            if viewModel.isCapturing {
                Circle()
                    .stroke(Color.starWhite.opacity(0.16), lineWidth: 4)
                    .frame(width: 78, height: 78)

                Circle()
                    .trim(from: 0, to: max(0.0001, min(1, viewModel.captureProgress)))
                    .stroke(
                        Color.appAccent,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 78, height: 78)
                    .animation(.linear(duration: 0.4), value: viewModel.captureProgress)
            } else {
                Circle()
                    .stroke(Color.appAccent, lineWidth: 3.5)
                    .frame(width: 76, height: 76)
            }
        }
    }

    private var captureCounter: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.starWhite)
                .frame(width: 18, height: 18)

            Text(L10nFormat.ratio(currentShotIndex, viewModel.numberOfShots))
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.starWhite.opacity(0.92))
        }
    }

    private var currentShotIndex: Int {
        Int(viewModel.captureProgress * Double(viewModel.numberOfShots))
    }
}
