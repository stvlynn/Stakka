import CoreLocation
import MapKit

@MainActor
final class DarkSkyViewModel: ObservableObject {
    @Published private(set) var selectedCoordinate: CLLocationCoordinate2D?
    @Published private(set) var currentReading: LightPollution?
    @Published var searchText = ""
    @Published private(set) var searchResults: [MKLocalSearchCompletion] = []

    private let fetchPollutionAtLocation: FetchPollutionAtLocationUseCase
    private let centerOnUserLocation: CenterOnUserLocationUseCase
    private let searchCompleter = MKLocalSearchCompleter()
    private var searchCompleterDelegate: SearchCompleterDelegate?

    let majorCities: [(coordinate: CLLocationCoordinate2D, name: String)] = [
        (CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074), "Beijing"),
        (CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737), "Shanghai"),
        (CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644), "Guangzhou"),
        (CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579), "Shenzhen"),
        (CLLocationCoordinate2D(latitude: 30.5728, longitude: 104.0668), "Chengdu"),
        (CLLocationCoordinate2D(latitude: 34.3416, longitude: 108.9398), "Xi'an"),
        (CLLocationCoordinate2D(latitude: 29.5630, longitude: 106.5516), "Chongqing"),
        (CLLocationCoordinate2D(latitude: 38.0428, longitude: 114.5149), "Shijiazhuang"),
        (CLLocationCoordinate2D(latitude: 36.6512, longitude: 117.1201), "Jinan"),
        (CLLocationCoordinate2D(latitude: 32.0603, longitude: 118.7969), "Nanjing"),
        (CLLocationCoordinate2D(latitude: 30.2936, longitude: 120.1614), "Hangzhou"),
        (CLLocationCoordinate2D(latitude: 26.0745, longitude: 119.2965), "Fuzhou"),
        (CLLocationCoordinate2D(latitude: 28.2282, longitude: 112.9388), "Changsha"),
        (CLLocationCoordinate2D(latitude: 30.5928, longitude: 114.3055), "Wuhan"),
        (CLLocationCoordinate2D(latitude: 22.8170, longitude: 108.3665), "Nanning"),
        (CLLocationCoordinate2D(latitude: 25.0408, longitude: 102.7123), "Kunming"),
        (CLLocationCoordinate2D(latitude: 36.0671, longitude: 103.8343), "Lanzhou"),
        (CLLocationCoordinate2D(latitude: 43.8256, longitude: 87.6168), "Urumqi"),
        (CLLocationCoordinate2D(latitude: 29.8683, longitude: 121.5440), "Ningbo"),
        (CLLocationCoordinate2D(latitude: 24.4798, longitude: 118.0894), "Xiamen"),
        (CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503), "Tokyo"),
        (CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), "Seoul"),
        (CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198), "Singapore"),
        (CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), "New York"),
        (CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437), "Los Angeles"),
        (CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278), "London"),
        (CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522), "Paris"),
    ]

    init(
        fetchPollutionAtLocation: FetchPollutionAtLocationUseCase,
        centerOnUserLocation: CenterOnUserLocationUseCase
    ) {
        self.fetchPollutionAtLocation = fetchPollutionAtLocation
        self.centerOnUserLocation = centerOnUserLocation
        setupSearchCompleter()
    }

    func loadCurrentLocation() async {
        let coordinate = await centerOnUserLocation.execute()
        await selectCoordinate(coordinate)
    }

    func selectCoordinate(_ coordinate: CLLocationCoordinate2D) async {
        selectedCoordinate = coordinate
        currentReading = try? await fetchPollutionAtLocation.execute(at: coordinate)
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
    }

    func updateSearchQuery() {
        if searchText.isEmpty {
            searchResults = []
        } else {
            searchCompleter.queryFragment = searchText
        }
    }

    func selectSearchResult(_ completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            if let item = response.mapItems.first {
                let coordinate = item.placemark.coordinate
                await selectCoordinate(coordinate)
                return coordinate
            }
        } catch {}
        return nil
    }

    private func setupSearchCompleter() {
        let delegate = SearchCompleterDelegate { [weak self] results in
            Task { @MainActor [weak self] in
                self?.searchResults = results
            }
        }
        searchCompleter.delegate = delegate
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        searchCompleterDelegate = delegate
    }
}

private final class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    let onUpdate: ([MKLocalSearchCompletion]) -> Void

    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
        super.init()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {}
}
