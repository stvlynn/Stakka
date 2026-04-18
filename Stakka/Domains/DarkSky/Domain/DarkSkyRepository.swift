import CoreLocation

protocol DarkSkyRepository {
    func pollution(at coordinate: CLLocationCoordinate2D) async throws -> LightPollution
}
