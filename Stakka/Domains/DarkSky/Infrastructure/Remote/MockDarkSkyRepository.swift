import CoreLocation

struct MockDarkSkyRepository: DarkSkyRepository, Sendable {
    func pollution(at coordinate: CLLocationCoordinate2D) async throws -> LightPollution {
        let normalizedLevel = abs(coordinate.latitude + coordinate.longitude).truncatingRemainder(dividingBy: 2.4)
        let bortleLevel: BortleLevel

        switch normalizedLevel {
        case ..<0.2: bortleLevel = .one
        case ..<0.4: bortleLevel = .two
        case ..<0.7: bortleLevel = .three
        case ..<1.0: bortleLevel = .four
        case ..<1.3: bortleLevel = .five
        case ..<1.6: bortleLevel = .six
        case ..<1.9: bortleLevel = .seven
        case ..<2.2: bortleLevel = .eight
        default: bortleLevel = .nine
        }

        return LightPollution(
            coordinate: coordinate,
            pollutionLevel: normalizedLevel,
            bortleLevel: bortleLevel,
            timestamp: Date()
        )
    }
}
