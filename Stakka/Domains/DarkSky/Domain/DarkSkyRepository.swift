import CoreLocation

protocol DarkSkyRepository: Sendable {
    func pollution(at coordinate: CLLocationCoordinate2D) async throws -> LightPollution
}
