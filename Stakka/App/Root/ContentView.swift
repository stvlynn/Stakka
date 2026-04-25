import SwiftUI

struct ContentView: View {
    private let darkSkyView: DarkSkyMapView
    private let cameraView: CameraView
    private let galleryView: GalleryView

    @State private var selectedTab = 0

    init(container: AppContainer) {
        darkSkyView = DarkSkyMapView(viewModel: container.makeDarkSkyViewModel())
        cameraView = CameraView(viewModel: container.makeCameraViewModel())
        galleryView = GalleryView(viewModel: container.makeLibraryViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.Tab.map, systemImage: "map.fill", value: 0) {
                darkSkyView
                    .accessibilityLabel(L10n.Tab.map)
                    .accessibilityIdentifier("tab.map")
            }

            Tab(L10n.Tab.capture, systemImage: "camera.fill", value: 1) {
                cameraView
                    .accessibilityLabel(L10n.Tab.capture)
                    .accessibilityIdentifier("tab.capture")
            }

            Tab(L10n.Tab.gallery, systemImage: "photo.on.rectangle.angled", value: 2) {
                galleryView
                    .accessibilityLabel(L10n.Tab.gallery)
                    .accessibilityIdentifier("tab.gallery")
            }
        }
        .tint(.appAccent)
        .background(Color.spaceBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
