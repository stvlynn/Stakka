import CoreLocation
import Foundation

struct CaptureSession: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let location: CLLocationCoordinate2D?
    let exposureTime: Double
    let numberOfShots: Int
    let imageIdentifiers: [String]
    let stackedImageIdentifier: String?

    enum CodingKeys: String, CodingKey {
        case id, date, latitude, longitude, exposureTime, numberOfShots, imageIdentifiers, stackedImageIdentifier
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        location: CLLocationCoordinate2D? = nil,
        exposureTime: Double,
        numberOfShots: Int,
        imageIdentifiers: [String] = [],
        stackedImageIdentifier: String? = nil
    ) {
        self.id = id
        self.date = date
        self.location = location
        self.exposureTime = exposureTime
        self.numberOfShots = numberOfShots
        self.imageIdentifiers = imageIdentifiers
        self.stackedImageIdentifier = stackedImageIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        exposureTime = try container.decode(Double.self, forKey: .exposureTime)
        numberOfShots = try container.decode(Int.self, forKey: .numberOfShots)
        imageIdentifiers = try container.decode([String].self, forKey: .imageIdentifiers)
        stackedImageIdentifier = try container.decodeIfPresent(String.self, forKey: .stackedImageIdentifier)

        if let latitude = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
        try container.encode(imageIdentifiers, forKey: .imageIdentifiers)
        try container.encodeIfPresent(stackedImageIdentifier, forKey: .stackedImageIdentifier)

        if let location {
            try container.encode(location.latitude, forKey: .latitude)
            try container.encode(location.longitude, forKey: .longitude)
        }
    }
}
