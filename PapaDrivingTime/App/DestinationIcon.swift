import SwiftUI

struct DestinationIcon: Identifiable {
    let id: String
    let emoji: String
    let label: String
    let background: Color
    let foreground: Color

    static let presets: [DestinationIcon] = [
        DestinationIcon(id: "🏠", emoji: "🏠", label: "Home",      background: Color(red: 1.0,  green: 0.93, blue: 0.87), foreground: Color(red: 0.85, green: 0.45, blue: 0.10)),
        DestinationIcon(id: "🏢", emoji: "🏢", label: "Work",      background: Color(red: 0.87, green: 0.95, blue: 0.88), foreground: Color(red: 0.10, green: 0.55, blue: 0.20)),
        DestinationIcon(id: "🏫", emoji: "🏫", label: "School",    background: Color(red: 0.87, green: 0.93, blue: 1.0),  foreground: Color(red: 0.10, green: 0.35, blue: 0.80)),
        DestinationIcon(id: "🏋️", emoji: "🏋️", label: "Gym",       background: Color(red: 0.93, green: 0.88, blue: 1.0),  foreground: Color(red: 0.42, green: 0.22, blue: 0.82)),
        DestinationIcon(id: "🛒", emoji: "🛒", label: "Shopping",  background: Color(red: 1.0,  green: 0.95, blue: 0.82), foreground: Color(red: 0.70, green: 0.46, blue: 0.00)),
        DestinationIcon(id: "🏥", emoji: "🏥", label: "Medical",   background: Color(red: 1.0,  green: 0.88, blue: 0.88), foreground: Color(red: 0.80, green: 0.15, blue: 0.15)),
        DestinationIcon(id: "🍽️", emoji: "🍽️", label: "Food",      background: Color(red: 1.0,  green: 0.91, blue: 0.88), foreground: Color(red: 0.80, green: 0.30, blue: 0.10)),
        DestinationIcon(id: "⛽", emoji: "⛽",  label: "Fuel",      background: Color(red: 0.88, green: 0.96, blue: 0.96), foreground: Color(red: 0.05, green: 0.50, blue: 0.55)),
        DestinationIcon(id: "🏖️", emoji: "🏖️", label: "Beach",    background: Color(red: 0.87, green: 0.95, blue: 1.0),  foreground: Color(red: 0.05, green: 0.45, blue: 0.75)),
        DestinationIcon(id: "🏟️", emoji: "🏟️", label: "Stadium",  background: Color(red: 0.95, green: 0.88, blue: 1.0),  foreground: Color(red: 0.55, green: 0.15, blue: 0.75)),
        DestinationIcon(id: "✈️", emoji: "✈️",  label: "Airport",  background: Color(red: 0.88, green: 0.93, blue: 1.0),  foreground: Color(red: 0.10, green: 0.30, blue: 0.75)),
        DestinationIcon(id: "📍", emoji: "📍",  label: "Other",    background: Color(red: 0.93, green: 0.93, blue: 0.93), foreground: Color(red: 0.40, green: 0.40, blue: 0.40)),
    ]

    static let `default` = presets.last!

    static func find(_ emoji: String) -> DestinationIcon {
        presets.first { $0.emoji == emoji } ?? .default
    }
}
