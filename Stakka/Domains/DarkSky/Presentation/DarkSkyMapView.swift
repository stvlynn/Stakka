import SwiftUI
import MapKit
import CoreLocation

struct DarkSkyMapView: View {
    @StateObject private var viewModel: DarkSkyViewModel
    @State private var cameraRegion: MKCoordinateRegion?
    @State private var showLocationPrimer = false
    @State private var locationAuthorization: CLAuthorizationStatus = CLLocationManager().authorizationStatus

    init(viewModel: DarkSkyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var showingResults: Bool {
        !viewModel.searchText.isEmpty && !viewModel.searchResults.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LightPollutionMapView(
                    selectedCoordinate: .constant(viewModel.selectedCoordinate),
                    cameraRegion: $cameraRegion,
                    onTap: { coordinate in
                        dismissSearch()
                        Task { await viewModel.selectCoordinate(coordinate) }
                    }
                )
                .ignoresSafeArea()

                VStack(spacing: Spacing.sm) {
                    Spacer()

                    if let reading = viewModel.currentReading, viewModel.searchText.isEmpty {
                        DarkSkyInfoCard(reading: reading)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.lg)
                .animation(AnimationPreset.smooth, value: showingResults)

                if showLocationPrimer {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { showLocationPrimer = false }

                    PermissionPrimerView(
                        kind: .location,
                        isDenied: isLocationDenied,
                        onAuthorize: requestLocation,
                        onDismiss: { showLocationPrimer = false }
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .animation(AnimationPreset.spring, value: showLocationPrimer)
            .navigationTitle(L10n.DarkSky.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(L10n.DarkSky.searchPlaceholder)
            ) {
                searchSuggestions
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.updateSearchQuery()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: locationButtonTapped) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Color.appAccent)
                    }
                    .accessibilityLabel(L10n.Accessibility.centerOnLocation)
                }
            }
            .task {
                // Seed the map with the fallback coordinate without requesting
                // authorization on launch — the primer drives the real request.
                if viewModel.selectedCoordinate == nil {
                    await viewModel.selectCoordinate(viewModel.defaultCoordinate)
                    cameraRegion = MKCoordinateRegion(
                        center: viewModel.defaultCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
                    )
                }
            }
        }
    }

    private var isLocationDenied: Bool {
        switch locationAuthorization {
        case .denied, .restricted: return true
        default: return false
        }
    }

    private func locationButtonTapped() {
        locationAuthorization = CLLocationManager().authorizationStatus
        switch locationAuthorization {
        case .notDetermined, .denied, .restricted:
            showLocationPrimer = true
        case .authorizedWhenInUse, .authorizedAlways:
            Task { await centerOnLocation() }
        @unknown default:
            showLocationPrimer = true
        }
    }

    private func requestLocation() {
        // Triggering the UseCase will cascade into CLLocationManager and, when
        // the status is notDetermined, show the real system prompt.
        showLocationPrimer = false
        Task {
            await centerOnLocation()
            // Re-read the status so subsequent taps land in the correct branch.
            locationAuthorization = CLLocationManager().authorizationStatus
        }
    }

    private func centerOnLocation() async {
        await viewModel.loadCurrentLocation()
        if let coord = viewModel.selectedCoordinate {
            cameraRegion = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            )
        }
    }

    @ViewBuilder
    private var searchSuggestions: some View {
        ForEach(viewModel.searchResults, id: \.self) { result in
            Button {
                selectSearchResult(result)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.stakkaCaption)
                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.stakkaSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        Task {
            if let coord = await viewModel.selectSearchResult(result) {
                viewModel.clearSearch()
                cameraRegion = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }

    private func dismissSearch() {
        viewModel.clearSearch()
    }
}
