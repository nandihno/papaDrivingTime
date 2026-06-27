import CoreLocation
import Foundation

enum DrivingDestinationSource: Equatable {
    case saved
    case calendar(eventID: String)
}

struct DrivingDestination: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    var title: String?
    var icon: String
    var targetArrivalHour: Int?
    var targetArrivalMinute: Int?
    var source: DrivingDestinationSource = .saved

    private enum CodingKeys: String, CodingKey {
        case id, name, address, latitude, longitude, title, icon, targetArrivalHour, targetArrivalMinute
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        address = try c.decode(String.self, forKey: .address)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "📍"
        targetArrivalHour = try c.decodeIfPresent(Int.self, forKey: .targetArrivalHour)
        targetArrivalMinute = try c.decodeIfPresent(Int.self, forKey: .targetArrivalMinute)
    }

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        title: String? = nil,
        icon: String = "📍",
        targetArrivalHour: Int? = nil,
        targetArrivalMinute: Int? = nil,
        source: DrivingDestinationSource = .saved
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        self.icon = icon
        self.targetArrivalHour = targetArrivalHour
        self.targetArrivalMinute = targetArrivalMinute
        self.source = source
    }

    var isCalendarSourced: Bool {
        if case .calendar = source { return true }
        return false
    }

    var displayName: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return name
    }

    var displaySubtitle: String { address }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var hasArrivalTarget: Bool {
        targetArrivalHour != nil && targetArrivalMinute != nil
    }

    var arrivalTargetDisplay: String? {
        guard let hour = targetArrivalHour, let minute = targetArrivalMinute else { return nil }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Arrive by \(formatter.string(from: date))"
    }

    func withTitle(_ title: String) -> DrivingDestination {
        var copy = self
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.title = trimmed.isEmpty ? nil : trimmed
        return copy
    }
}
