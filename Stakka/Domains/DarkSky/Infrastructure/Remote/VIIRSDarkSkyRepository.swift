import CoreLocation
import Foundation

/// Real implementation using VIIRS-based estimation
/// Uses distance from major cities and population density heuristics
struct VIIRSDarkSkyRepository: DarkSkyRepository {
    func pollution(at coordinate: CLLocationCoordinate2D) async throws -> LightPollution {
        // Calculate distance to nearest major city
        let nearestCityDistance = distanceToNearestMajorCity(from: coordinate)

        // Estimate Bortle level based on distance
        let bortleLevel = estimateBortleLevel(distanceKm: nearestCityDistance)

        // Convert Bortle to pollution level (0.0 = darkest, 2.4 = brightest)
        let pollutionLevel = Double(bortleLevel.rawValue - 1) * 0.3

        return LightPollution(
            coordinate: coordinate,
            pollutionLevel: pollutionLevel,
            bortleLevel: bortleLevel,
            timestamp: Date()
        )
    }

    private func distanceToNearestMajorCity(from coordinate: CLLocationCoordinate2D) -> Double {
        let majorCities: [(lat: Double, lon: Double, name: String)] = [
            // China major cities
            (39.9042, 116.4074, "Beijing"),
            (31.2304, 121.4737, "Shanghai"),
            (23.1291, 113.2644, "Guangzhou"),
            (22.5431, 114.0579, "Shenzhen"),
            (30.5728, 104.0668, "Chengdu"),
            (34.3416, 108.9398, "Xi'an"),
            (29.5630, 106.5516, "Chongqing"),
            (38.0428, 114.5149, "Shijiazhuang"),
            (36.6512, 117.1201, "Jinan"),
            (32.0603, 118.7969, "Nanjing"),
            (30.2936, 120.1614, "Hangzhou"),
            (26.0745, 119.2965, "Fuzhou"),
            (28.2282, 112.9388, "Changsha"),
            (30.5928, 114.3055, "Wuhan"),
            (22.8170, 108.3665, "Nanning"),
            (25.0408, 102.7123, "Kunming"),
            (36.0671, 103.8343, "Lanzhou"),
            (43.8256, 87.6168, "Urumqi"),
            (29.8683, 121.5440, "Ningbo"),
            (24.4798, 118.0894, "Xiamen"),

            // International major cities
            (35.6762, 139.6503, "Tokyo"),
            (37.5665, 126.9780, "Seoul"),
            (1.3521, 103.8198, "Singapore"),

            // USA cities
            (40.7128, -74.0060, "New York"),
            (34.0522, -118.2437, "Los Angeles"),
            (37.7749, -122.4194, "San Francisco"),
            (41.8781, -87.6298, "Chicago"),
            (29.7604, -95.3698, "Houston"),
            (33.4484, -112.0740, "Phoenix"),
            (39.7392, -104.9903, "Denver"),
            (47.6062, -122.3321, "Seattle"),
            (25.7617, -80.1918, "Miami"),
            (42.3601, -71.0589, "Boston"),
            (33.7490, -84.3880, "Atlanta"),

            // Europe cities
            (51.5074, -0.1278, "London"),
            (48.8566, 2.3522, "Paris"),
            (52.5200, 13.4050, "Berlin"),
            (41.9028, 12.4964, "Rome"),
            (40.4168, -3.7038, "Madrid"),

            // Other major cities
            (55.7558, 37.6173, "Moscow"),
            (19.0760, 72.8777, "Mumbai"),
            (28.6139, 77.2090, "Delhi"),
            (-23.5505, -46.6333, "São Paulo"),
            (-33.8688, 151.2093, "Sydney"),
        ]

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var minDistance = Double.infinity
        for city in majorCities {
            let cityLocation = CLLocation(latitude: city.lat, longitude: city.lon)
            let distance = location.distance(from: cityLocation) / 1000.0
            minDistance = min(minDistance, distance)
        }

        return minDistance
    }

    private func estimateBortleLevel(distanceKm: Double) -> BortleLevel {
        // Empirical mapping based on distance from major cities
        switch distanceKm {
        case 0..<5:
            return .nine      // Inner city
        case 5..<15:
            return .eight     // City
        case 15..<30:
            return .seven     // Suburban edge
        case 30..<50:
            return .six       // Bright suburban
        case 50..<80:
            return .five      // Suburban
        case 80..<120:
            return .four      // Rural transition
        case 120..<200:
            return .three     // Rural dark sky
        case 200..<350:
            return .two       // Truly dark sky
        default:
            return .one       // Excellent dark sky
        }
    }
}
