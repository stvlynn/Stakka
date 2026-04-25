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
        HStack(spacing: Spacing.sm) {
            hudSegment(icon: "camera.aperture", value: aperture)
            divider
            hudSegment(icon: "timer", value: shutterSpeed)
            divider
            hudSegment(icon: "dot.circle.and.cursorarrow", value: iso)
            divider
            hudSegment(icon: "plus.magnifyingglass", value: zoom)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .liquidGlassPill()
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
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
            Text(value)
                .font(.stakkaNumericSmall)
                .foregroundStyle(Color.starWhite)
        }
    }

    private var divider: some View {
        Circle()
            .fill(Color.textTertiary.opacity(0.6))
            .frame(width: 3, height: 3)
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
