import CoreLocation

struct CenterOnUserLocationUseCase {
    private let locationService: CoreLocationService
    private let fallbackCoordinate = CLLocationCoordinate2D(latitude: 35.6824, longitude: 139.7690)

    init(locationService: CoreLocationService) {
        self.locationService = locationService
    }

    func execute() async -> CLLocationCoordinate2D {
        do {
            return try await locationService.requestCurrentLocation() ?? fallbackCoordinate
        } catch {
            return fallbackCoordinate
        }
    }
}
