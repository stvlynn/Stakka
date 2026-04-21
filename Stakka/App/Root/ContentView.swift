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
        ZStack {
            Color.spaceBackground
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                darkSkyView
                    .tabItem {
                        Label(L10n.Tab.map, systemImage: "map.fill")
                    }
                    .tag(0)

                cameraView
                    .tabItem {
                        Label(L10n.Tab.capture, systemImage: "camera.fill")
                    }
                    .tag(1)

                galleryView
                    .tabItem {
                        Label(L10n.Tab.gallery, systemImage: "photo.on.rectangle.angled")
                    }
                    .tag(2)
            }
            .tint(.cosmicBlue)
        }
        .preferredColorScheme(.dark)
    }
}
