import SwiftUI
import MapKit

struct LightPollutionMapContent: MapContent {
    let cities: [(coordinate: CLLocationCoordinate2D, name: String)]

    var body: some MapContent {
        ForEach(Array(cities.enumerated()), id: \.offset) { _, city in
            pollutionZones(for: city.coordinate)
        }
    }

    @MapContentBuilder
    private func pollutionZones(for coordinate: CLLocationCoordinate2D) -> some MapContent {
        MapCircle(center: coordinate, radius: 5_000)
            .foregroundStyle(BortleLevel.nine.mapColor.opacity(0.35))
            .stroke(.clear, lineWidth: 0)

        MapCircle(center: coordinate, radius: 15_000)
            .foregroundStyle(BortleLevel.eight.mapColor.opacity(0.25))
            .stroke(.clear, lineWidth: 0)

        MapCircle(center: coordinate, radius: 30_000)
            .foregroundStyle(BortleLevel.seven.mapColor.opacity(0.20))
            .stroke(.clear, lineWidth: 0)

        MapCircle(center: coordinate, radius: 50_000)
            .foregroundStyle(BortleLevel.six.mapColor.opacity(0.15))
            .stroke(.clear, lineWidth: 0)

        MapCircle(center: coordinate, radius: 80_000)
            .foregroundStyle(BortleLevel.five.mapColor.opacity(0.10))
            .stroke(.clear, lineWidth: 0)

        MapCircle(center: coordinate, radius: 120_000)
            .foregroundStyle(BortleLevel.four.mapColor.opacity(0.08))
            .stroke(.clear, lineWidth: 0)
    }
}
