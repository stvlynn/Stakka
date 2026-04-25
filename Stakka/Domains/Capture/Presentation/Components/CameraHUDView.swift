import SwiftUI

/// A slim, translucent heads-up readout that lives above the camera preview.
/// Shows aperture / shutter / ISO / zoom so the user can confirm the active
/// shooting parameters at a glance while the capsule control row stays focused
/// on the primary capture actions.
struct CameraHUDView: View {
    let aperture: String
    let shutterSpeed: String
    let iso: String
    let zoom: String

    var body: some View {
        HStack(spacing: 0) {
            hudSegment(icon: "camera.aperture", value: aperture)
            hudSegment(icon: "timer", value: shutterSpeed)
            hudSegment(icon: "dot.circle.and.cursorarrow", value: iso)
            hudSegment(icon: "plus.magnifyingglass", value: zoom)
        }
        .frame(height: 56)
        .padding(.horizontal, Spacing.sm)
        .systemGlassPill()
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(L10n.Camera.aperture) \(aperture), "
            + "\(L10n.Camera.shutter) \(shutterSpeed), "
            + "\(iso), "
            + "\(L10n.Camera.zoom) \(zoom)"
        )
    }

    private func hudSegment(icon: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.starWhite)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        }
        .frame(width: 54)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("HUD") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            CameraHUDView(aperture: "f/1.8", shutterSpeed: "1/30", iso: "ISO 1600", zoom: "1×")
            Spacer()
        }
        .padding()
    }
}
#endif
