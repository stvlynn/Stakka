import CoreLocation
import MapKit

@MainActor
final class DarkSkyViewModel: ObservableObject {
    @Published private(set) var selectedCoordinate: CLLocationCoordinate2D?
    @Published private(set) var currentReading: LightPollution?

    private let fetchPollutionAtLocation: FetchPollutionAtLocationUseCase
    private let centerOnUserLocation: CenterOnUserLocationUseCase

    init(
        fetchPollutionAtLocation: FetchPollutionAtLocationUseCase,
        centerOnUserLocation: CenterOnUserLocationUseCase
    ) {
        self.fetchPollutionAtLocation = fetchPollutionAtLocation
        self.centerOnUserLocation = centerOnUserLocation
    }

    func loadCurrentLocation() async {
        let coordinate = await centerOnUserLocation.execute()
        await selectCoordinate(coordinate)
    }

    func selectCoordinate(_ coordinate: CLLocationCoordinate2D) async {
        selectedCoordinate = coordinate
        currentReading = try? await fetchPollutionAtLocation.execute(at: coordinate)
    }
}
