import Foundation
import CoreLocation

struct LightPollutionData: Codable {
    let latitude: Double
    let longitude: Double
    let pollutionLevel: Double
    let classification: PollutionClassification
    let timestamp: Date

    enum PollutionClassification: String, Codable {
        case excellent = "Class 1 - Excellent Dark Sky"
        case good = "Class 2 - Good Dark Sky"
        case rural = "Class 3 - Rural Sky"
        case ruralSuburban = "Class 4 - Rural/Suburban Transition"
        case suburban = "Class 5 - Suburban Sky"
        case brightSuburban = "Class 6 - Bright Suburban Sky"
        case suburbanUrban = "Class 7 - Suburban/Urban Transition"
        case city = "Class 8 - City Sky"
        case innerCity = "Class 9 - Inner City Sky"

        static func from(level: Double) -> PollutionClassification {
            switch level {
            case 0..<0.01: return .excellent
            case 0.01..<0.06: return .good
            case 0.06..<0.16: return .rural
            case 0.16..<0.33: return .ruralSuburban
            case 0.33..<0.60: return .suburban
            case 0.60..<1.0: return .brightSuburban
            case 1.0..<2.0: return .suburbanUrban
            case 2.0..<4.0: return .city
            default: return .innerCity
            }
        }
    }
}

struct CaptureSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let location: CLLocationCoordinate2D?
    let exposureTime: Double
    let numberOfShots: Int
    let images: [String]
    let stackedImagePath: String?

    enum CodingKeys: String, CodingKey {
        case id, date, latitude, longitude, exposureTime, numberOfShots, images, stackedImagePath
    }

    init(id: UUID = UUID(), date: Date = Date(), location: CLLocationCoordinate2D? = nil,
         exposureTime: Double, numberOfShots: Int, images: [String] = [], stackedImagePath: String? = nil) {
        self.id = id
        self.date = date
        self.location = location
        self.exposureTime = exposureTime
        self.numberOfShots = numberOfShots
        self.images = images
        self.stackedImagePath = stackedImagePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        exposureTime = try container.decode(Double.self, forKey: .exposureTime)
        numberOfShots = try container.decode(Int.self, forKey: .numberOfShots)
        images = try container.decode([String].self, forKey: .images)
        stackedImagePath = try container.decodeIfPresent(String.self, forKey: .stackedImagePath)

        if let lat = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let lon = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            location = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(exposureTime, forKey: .exposureTime)
        try container.encode(numberOfShots, forKey: .numberOfShots)
        try container.encode(images, forKey: .images)
        try container.encodeIfPresent(stackedImagePath, forKey: .stackedImagePath)

        if let location = location {
            try container.encode(location.latitude, forKey: .latitude)
            try container.encode(location.longitude, forKey: .longitude)
        }
    }
}
