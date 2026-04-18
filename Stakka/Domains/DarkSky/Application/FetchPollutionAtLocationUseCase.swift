import CoreLocation

struct FetchPollutionAtLocationUseCase {
    private let repository: DarkSkyRepository

    init(repository: DarkSkyRepository) {
        self.repository = repository
    }

    func execute(at coordinate: CLLocationCoordinate2D) async throws -> LightPollution {
        try await repository.pollution(at: coordinate)
    }
}
