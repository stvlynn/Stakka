import SwiftUI
import MapKit

struct DarkSkyMapView: View {
    @StateObject private var viewModel: DarkSkyViewModel
    @State private var position: MapCameraPosition = .automatic

    init(viewModel: DarkSkyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                Map(position: $position) {
                    if let coordinate = viewModel.selectedCoordinate {
                        Marker("暗空点", coordinate: coordinate)
                            .tint(Color.cosmicBlue)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .preferredColorScheme(.dark)

                VStack {
                    Spacer()
                    if let reading = viewModel.currentReading {
                        DarkSkyInfoCard(reading: reading)
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.lg)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("光污染地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.loadCurrentLocation()
                            position = .region(
                                MKCoordinateRegion(
                                    center: viewModel.selectedCoordinate ?? CLLocationCoordinate2D(latitude: 35.6824, longitude: 139.7690),
                                    span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
                                )
                            )
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Color.cosmicBlue)
                    }
                }
            }
            .task {
                guard viewModel.selectedCoordinate == nil else { return }
                await viewModel.loadCurrentLocation()

                if let coordinate = viewModel.selectedCoordinate {
                    position = .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
                        )
                    )
                }
            }
        }
    }
}
