import Foundation

// MARK: - DrivingProvider

enum DrivingProvider: String {
    case apple
    case google
}

// MARK: - DrivingTimeEstimate

struct DrivingTimeEstimate: Identifiable {
    let destination: DrivingDestination
    let travelMinutes: Int?
    let delayMinutes: Int?
    let advisory: String?
    let hasDelay: Bool
    let errorMessage: String?

    var id: UUID { destination.id }
    var isAvailable: Bool { travelMinutes != nil && errorMessage == nil }

    static func orderedForDisplay(_ estimates: [DrivingTimeEstimate]) -> [DrivingTimeEstimate] {
        estimates.enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element
                let right = rhs.element
                let leftIsCalendar = left.destination.isCalendarSourced
                let rightIsCalendar = right.destination.isCalendarSourced

                if leftIsCalendar != rightIsCalendar {
                    return leftIsCalendar
                }

                if leftIsCalendar {
                    return lhs.offset < rhs.offset
                }

                switch (left.travelMinutes, right.travelMinutes) {
                case let (leftMinutes?, rightMinutes?):
                    if leftMinutes != rightMinutes {
                        return leftMinutes < rightMinutes
                    }
                    return lhs.offset < rhs.offset
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }

    static func unavailable(destination: DrivingDestination, message: String) -> DrivingTimeEstimate {
        DrivingTimeEstimate(
            destination: destination,
            travelMinutes: nil,
            delayMinutes: nil,
            advisory: nil,
            hasDelay: false,
            errorMessage: message
        )
    }

    func minutesUntilDeparture(now: Date = Date()) -> Int? {
        guard let departureDeadline = departureDeadline(now: now) else { return nil }
        let secondsLeft = departureDeadline.timeIntervalSince(now)
        return Int((secondsLeft / 60).rounded())
    }

    func approximateArrivalTime(now: Date = Date()) -> Date? {
        guard let travelMinutes else { return nil }
        return now.addingTimeInterval(Double(travelMinutes) * 60)
    }

    func approximateArrivalDisplay(now: Date = Date()) -> String? {
        guard let arrivalTime = approximateArrivalTime(now: now) else { return nil }
        let time = arrivalTime.formatted(date: .omitted, time: .shortened)
        return "ETA \(time)"
    }

    func departureDeadline(now: Date = Date()) -> Date? {
        guard let travelMinutes, let hour = destination.targetArrivalHour,
              let minute = destination.targetArrivalMinute else { return nil }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard var arrivalDate = calendar.date(from: components) else { return nil }

        if arrivalDate < now {
            arrivalDate = calendar.date(byAdding: .day, value: 1, to: arrivalDate) ?? arrivalDate
        }

        return arrivalDate.addingTimeInterval(-Double(travelMinutes) * 60)
    }

    func countdownText(now: Date = Date()) -> String? {
        guard let departureDeadline = departureDeadline(now: now),
              let mins = minutesUntilDeparture(now: now) else { return nil }

        if mins >= -5, mins <= 5 {
            return "Depart now"
        }

        let time = departureDeadline.formatted(date: .omitted, time: .shortened)
        return mins < -5 ? "Leave time passed" : "Leave at \(time)"
    }

    var countdownUrgency: CountdownUrgency {
        guard let mins = minutesUntilDeparture() else { return .none }
        if mins > 30 { return .comfortable }
        if mins > 10 { return .soon }
        return .urgent
    }
}

enum CountdownUrgency {
    case none, comfortable, soon, urgent
}
