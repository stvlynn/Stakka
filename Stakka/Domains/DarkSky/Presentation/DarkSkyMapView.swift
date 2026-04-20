import SwiftUI
import MapKit

struct DarkSkyMapView: View {
    @StateObject private var viewModel: DarkSkyViewModel
    @State private var cameraRegion: MKCoordinateRegion?

    init(viewModel: DarkSkyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LightPollutionMapView(
                    selectedCoordinate: .constant(viewModel.selectedCoordinate),
                    cameraRegion: $cameraRegion,
                    onTap: { coordinate in
                        Task { await viewModel.selectCoordinate(coordinate) }
                    }
                )
                .ignoresSafeArea()

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
            .navigationTitle(L10n.DarkSky.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.loadCurrentLocation()
                            if let coord = viewModel.selectedCoordinate {
                                cameraRegion = MKCoordinateRegion(
                                    center: coord,
                                    span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Color.cosmicBlue)
                    }
                    .accessibilityLabel(L10n.Accessibility.centerOnLocation)
                }
            }
            .task {
                guard viewModel.selectedCoordinate == nil else { return }
                await viewModel.loadCurrentLocation()
                if let coord = viewModel.selectedCoordinate {
                    cameraRegion = MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
                    )
                }
            }
        }
    }
}
