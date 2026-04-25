import CoreLocation

struct FetchPollutionAtLocationUseCase: Sendable {
    private let repository: any DarkSkyRepository

    init(repository: any DarkSkyRepository) {
        self.repository = repository
    }

    func execute(at coordinate: CLLocationCoordinate2D) async throws -> LightPollution {
        try await repository.pollution(at: coordinate)
    }
}
