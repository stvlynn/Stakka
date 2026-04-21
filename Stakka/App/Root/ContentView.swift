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
            darkSkyView
                .tabItem {
                    Label(L10n.Tab.map, systemImage: "map.fill")
                }
                .tag(0)
                .accessibilityLabel(L10n.Tab.map)
                .accessibilityIdentifier("tab.map")

            cameraView
                .tabItem {
                    Label(L10n.Tab.capture, systemImage: "camera.fill")
                }
                .tag(1)
                .accessibilityLabel(L10n.Tab.capture)
                .accessibilityIdentifier("tab.capture")

            galleryView
                .tabItem {
                    Label(L10n.Tab.gallery, systemImage: "photo.on.rectangle.angled")
                }
                .tag(2)
                .accessibilityLabel(L10n.Tab.gallery)
                .accessibilityIdentifier("tab.gallery")
        }
        .tint(.cosmicBlue)
        .background(Color.spaceBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
