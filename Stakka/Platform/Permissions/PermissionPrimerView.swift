import SwiftUI
import UIKit

/// The capability a `PermissionPrimerView` is asking the user to unlock.
enum PermissionKind {
    case location
    case camera
    case photos

    fileprivate var systemImage: String {
        switch self {
        case .location: return "location.circle.fill"
        case .camera: return "camera.circle.fill"
        case .photos: return "photo.on.rectangle.angled"
        }
    }

    fileprivate var glowColor: Color {
        switch self {
        case .location: return .cosmicBlue
        case .camera: return .cosmicBlue
        case .photos: return .nebulaPurple
        }
    }

    fileprivate func title(denied: Bool) -> String {
        switch (self, denied) {
        case (.location, false): return L10n.Permissions.locationTitle
        case (.location, true): return L10n.Permissions.locationDeniedTitle
        case (.camera, false): return L10n.Permissions.cameraTitle
        case (.camera, true): return L10n.Permissions.cameraDeniedTitle
        case (.photos, false): return L10n.Permissions.photosTitle
        case (.photos, true): return L10n.Permissions.photosDeniedTitle
        }
    }

    fileprivate func body(denied: Bool) -> String {
        switch (self, denied) {
        case (.location, false): return L10n.Permissions.locationBody
        case (.location, true): return L10n.Permissions.locationDeniedBody
        case (.camera, false): return L10n.Permissions.cameraBody
        case (.camera, true): return L10n.Permissions.cameraDeniedBody
        case (.photos, false): return L10n.Permissions.photosBody
        case (.photos, true): return L10n.Permissions.photosDeniedBody
        }
    }

    fileprivate var allowTitle: String {
        switch self {
        case .location: return L10n.Permissions.locationAllow
        case .camera: return L10n.Permissions.cameraAllow
        case .photos: return L10n.Permissions.photosAllow
        }
    }
}

/// Reusable pre-permission primer card.
///
/// - Parameters:
///   - kind: which capability this primer represents.
///   - isDenied: when `true`, the card switches to a "denied" state that offers
///     an "Open Settings" deep-link instead of triggering the system prompt.
///   - onAuthorize: invoked when the user taps the primary button in the
///     undetermined state. The caller is responsible for calling the actual
///     system request (e.g. `CLLocationManager.requestWhenInUseAuthorization()`
///     or `AVCaptureDevice.requestAccess(for:)`).
///   - onDismiss: invoked when the user taps "Not Now". Optional.
struct PermissionPrimerView: View {
    let kind: PermissionKind
    let isDenied: Bool
    let onAuthorize: () -> Void
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(Color.starWhite)
                .breathingGlow(color: kind.glowColor, radius: 12)
                .padding(.top, Spacing.sm)

            Text(kind.title(denied: isDenied))
                .font(.stakkaHeadline)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(kind.body(denied: isDenied))
                .font(.stakkaBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Spacing.sm) {
                Button {
                    if isDenied {
                        openSystemSettings()
                    } else {
                        onAuthorize()
                    }
                } label: {
                    Text(isDenied ? L10n.Permissions.openSettings : kind.allowTitle)
                        .font(.stakkaCaption)
                        .foregroundStyle(Color.starWhite)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: Spacing.touchTarget)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .fill(Color.cosmicBlue)
                        )
                }
                .buttonStyle(.plain)

                if let onDismiss {
                    Button(action: onDismiss) {
                        Text(L10n.Permissions.notNow)
                            .font(.stakkaCaption)
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: Spacing.touchTarget)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 360)
        .glassCard()
        .continuousCorners(CornerRadius.lg)
        .padding(.horizontal, Spacing.lg)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#if DEBUG
#Preview("Primer – Location (undetermined)") {
    ZStack {
        Color.spaceBackground.ignoresSafeArea()
        PermissionPrimerView(kind: .location, isDenied: false, onAuthorize: {}, onDismiss: {})
    }
}

#Preview("Primer – Camera (denied)") {
    ZStack {
        Color.spaceBackground.ignoresSafeArea()
        PermissionPrimerView(kind: .camera, isDenied: true, onAuthorize: {})
    }
}
#endif
