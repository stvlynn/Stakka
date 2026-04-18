import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.spaceBackground
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                LightPollutionMapView()
                    .tabItem {
                        Label("地图", systemImage: "map.fill")
                    }
                    .tag(0)

                CameraView()
                    .tabItem {
                        Label("拍摄", systemImage: "camera.fill")
                    }
                    .tag(1)

                LibraryStackingView()
                    .tabItem {
                        Label("堆栈", systemImage: "square.stack.3d.up.fill")
                    }
                    .tag(2)
            }
            .tint(.cosmicBlue)
        }
        .preferredColorScheme(.dark)
    }
}
