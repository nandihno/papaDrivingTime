import SwiftUI

struct DrivingDestinationRowView: View {
    let estimate: DrivingTimeEstimate
    let provider: DrivingProvider
    var now: Date = Date()

    @Environment(\.openURL) private var openURL

    // MARK: - Derived state

    private var cardIcon: DestinationIcon {
        estimate.destination.isCalendarSourced
            ? DestinationIcon(id: "cal", emoji: "📅", label: "Calendar",
                              background: Color(red: 0.88, green: 0.90, blue: 1.0),
                              foreground: Color(red: 0.28, green: 0.18, blue: 0.82))
            : DestinationIcon.find(estimate.destination.icon)
    }

    private var urgencyColor: Color {
        guard estimate.isAvailable else { return Color(.systemGray4) }
        switch estimate.countdownUrgency {
        case .urgent:      return AppTheme.danger
        case .soon:        return AppTheme.warning
        case .comfortable: return AppTheme.success
        case .none:
            return estimate.hasDelay ? AppTheme.warning : AppTheme.success
        }
    }

    private var travelColor: Color { urgencyColor }

    private func openInMaps() {
        let dest = estimate.destination
        switch provider {
        case .apple:
            if let url = URL(string: "http://maps.apple.com/?daddr=\(dest.latitude),\(dest.longitude)&dirflg=d") {
                openURL(url)
            }
        case .google:
            let appURL = URL(string: "comgooglemaps://?daddr=\(dest.latitude),\(dest.longitude)&directionsmode=driving")!
            let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(dest.latitude),\(dest.longitude)&travelmode=driving")!
            openURL(appURL) { accepted in
                if !accepted { openURL(webURL) }
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            urgencyBar
            cardContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Urgency bar

    private var urgencyBar: some View {
        urgencyColor
            .frame(maxWidth: .infinity)
            .frame(height: 4)
    }

    // MARK: - Card content

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Top row: icon + name + travel time
            HStack(alignment: .top, spacing: 12) {
                iconBadge

                VStack(alignment: .leading, spacing: 2) {
                    Text(estimate.destination.displayName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(estimate.destination.displaySubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                travelTimeBlock
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            // Bottom row: pills + Go button
            HStack(alignment: .center, spacing: 8) {
                pillRow
                Spacer(minLength: 4)
                goButton
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Icon badge

    private var iconBadge: some View {
        Text(cardIcon.emoji)
            .font(.system(size: 22))
            .frame(width: 44, height: 44)
            .background(cardIcon.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Travel time block

    @ViewBuilder
    private var travelTimeBlock: some View {
        if let errorMessage = estimate.errorMessage {
            VStack(alignment: .trailing, spacing: 2) {
                Text("—")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color(.systemGray3))
                Text(errorMessage.count > 30 ? "Route unavailable" : errorMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
            }
        } else if let travelMinutes = estimate.travelMinutes {
            let (value, unit) = travelMinutes.durationComponents
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(travelColor)
                    Text(unit)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(travelColor)
                }
            }
        }
    }

    // MARK: - Pills

    @ViewBuilder
    private var pillRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Delay / clear status pill
            if estimate.isAvailable {
                if let delay = estimate.delayMinutes, delay > 0 {
                    pill(icon: "⚠️", text: "+\(delay) min delay", bg: Color.orange.opacity(0.15), fg: Color(red: 0.65, green: 0.35, blue: 0.00))
                } else if estimate.hasDelay {
                    pill(icon: "🚦", text: estimate.advisory ?? "Traffic reported", bg: Color.orange.opacity(0.15), fg: Color(red: 0.65, green: 0.35, blue: 0.00))
                } else {
                    pill(icon: "✅", text: "Clear roads", bg: Color.green.opacity(0.12), fg: Color(red: 0.10, green: 0.50, blue: 0.20))
                }
            }

            // Arrival target or countdown
            if let countdown = estimate.countdownText(now: now) {
                let (pillBg, pillFg) = countdownColors(urgency: estimate.countdownUrgency)
                pill(icon: countdownIcon(urgency: estimate.countdownUrgency), text: countdown, bg: pillBg, fg: pillFg)
            } else if let arrivalDisplay = estimate.destination.arrivalTargetDisplay {
                pill(icon: "🕐", text: arrivalDisplay, bg: Color.blue.opacity(0.10), fg: Color(red: 0.10, green: 0.30, blue: 0.75))
            }
        }
    }

    private func pill(icon: String, text: String, bg: Color, fg: Color) -> some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: 11))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(fg)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(bg)
        .clipShape(Capsule())
    }

    private func countdownColors(urgency: CountdownUrgency) -> (Color, Color) {
        switch urgency {
        case .none:        return (Color.gray.opacity(0.12),   Color(.secondaryLabel))
        case .comfortable: return (Color.green.opacity(0.12),  Color(red: 0.10, green: 0.50, blue: 0.20))
        case .soon:        return (Color.orange.opacity(0.15), Color(red: 0.65, green: 0.35, blue: 0.00))
        case .urgent:      return (Color.red.opacity(0.12),    Color(red: 0.75, green: 0.10, blue: 0.10))
        }
    }

    private func countdownIcon(urgency: CountdownUrgency) -> String {
        switch urgency {
        case .none:        return "🕐"
        case .comfortable: return "🟢"
        case .soon:        return "🟡"
        case .urgent:      return "🔴"
        }
    }

    // MARK: - Go button

    private var goButton: some View {
        Button(action: openInMaps) {
            HStack(spacing: 4) {
                Text("Go")
                    .font(.system(size: 13, weight: .bold))
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Color(.systemBackground))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.label))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open directions to \(estimate.destination.displayName)")
    }
}
