import Foundation
import CoreLocation

struct LightPollution: Sendable {
    let coordinate: CLLocationCoordinate2D
    let pollutionLevel: Double
    let bortleLevel: BortleLevel
    let timestamp: Date
}
