import CarPlay
import CoreLocation
import Foundation
import MapKit
import UIKit

@MainActor
final class CarPlayController {
    private let interfaceController: CPInterfaceController
    private weak var carPlayScene: CPTemplateApplicationScene?
    private let listTemplate: CPListTemplate
    private var refreshTask: Task<Void, Never>?
    private var currentEstimates: [DrivingTimeEstimate] = []

    private var provider: DrivingProvider {
        let raw = UserDefaults.standard.string(forKey: "drivingProvider") ?? DrivingProvider.apple.rawValue
        return DrivingProvider(rawValue: raw) ?? .apple
    }

    private var googleApiKey: String {
        UserDefaults.standard.string(forKey: "googleMapsApiKey") ?? ""
    }

    init(interfaceController: CPInterfaceController, carPlayScene: CPTemplateApplicationScene) {
        self.interfaceController = interfaceController
        self.carPlayScene = carPlayScene
        self.listTemplate = CPListTemplate(title: "Driving Times", sections: [])
        interfaceController.setRootTemplate(listTemplate, animated: false, completion: nil)

        Task { await fetchAndRefresh() }

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await fetchAndRefresh()
            }
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    // MARK: - Fetch

    private func fetchAndRefresh() async {
        let calendarDests = await CalendarDestinationService.shared.fetchUpcomingTodayDestinations()
        let allDests = calendarDests + DrivingDestinationStore.shared.all

        if currentEstimates.isEmpty {
            listTemplate.updateSections([loadingSection()])
        }

        do {
            let estimates = try await DrivingTimeService.shared.fetchDrivingTimes(
                provider: provider,
                googleApiKey: googleApiKey,
                destinations: allDests
            )
            currentEstimates = estimates
            listTemplate.updateSections([buildSection(from: estimates)])
        } catch {
            if currentEstimates.isEmpty {
                listTemplate.updateSections([singleItemSection(text: "Error", detail: "Could not fetch driving times.")])
            }
        }
    }

    // MARK: - Section builders

    private func loadingSection() -> CPListSection {
        singleItemSection(text: "Updating…", detail: "Fetching driving times")
    }

    private func singleItemSection(text: String, detail: String) -> CPListSection {
        CPListSection(items: [CPListItem(text: text, detailText: detail)])
    }

    private func buildSection(from estimates: [DrivingTimeEstimate]) -> CPListSection {
        guard !estimates.isEmpty else {
            return singleItemSection(text: "No Destinations", detail: "Add destinations in the PapaDrivingTime app")
        }
        return CPListSection(items: estimates.map { buildListItem(for: $0) })
    }

    private func buildListItem(for estimate: DrivingTimeEstimate) -> CPListItem {
        let emoji = estimate.destination.isCalendarSourced ? "📅" : estimate.destination.icon
        let color = statusColor(for: estimate)
        let item = CPListItem(
            text: estimate.destination.displayName,
            detailText: detailText(for: estimate),
            image: emojiImage(emoji, background: color),
            accessoryImage: statusSymbol(for: estimate, color: color),
            accessoryType: .disclosureIndicator
        )
        item.handler = { [weak self] _, completion in
            Task { @MainActor [weak self] in
                self?.showNavigationChoice(for: estimate)
                completion()
            }
        }
        return item
    }

    // MARK: - Status visuals

    private func statusColor(for estimate: DrivingTimeEstimate) -> UIColor {
        guard estimate.travelMinutes != nil else { return .systemGray }
        if let mins = estimate.minutesUntilDeparture(now: Date()) {
            if mins <= 10 { return .systemRed }
            if mins <= 30 { return .systemOrange }
            return estimate.hasDelay ? .systemOrange : .systemGreen
        }
        return estimate.hasDelay ? .systemOrange : .systemGreen
    }

    private func statusSymbol(for estimate: DrivingTimeEstimate, color: UIColor) -> UIImage? {
        guard estimate.travelMinutes != nil else {
            return symbolImage("questionmark.circle.fill", color: .systemGray)
        }
        if let mins = estimate.minutesUntilDeparture(now: Date()) {
            if mins <= 5  { return symbolImage("exclamationmark.circle.fill", color: color) }
            if mins <= 10 { return symbolImage("clock.fill", color: color) }
            if mins <= 30 { return symbolImage("clock.fill", color: color) }
            return estimate.hasDelay
                ? symbolImage("exclamationmark.triangle.fill", color: color)
                : symbolImage("checkmark.circle.fill", color: color)
        }
        return estimate.hasDelay
            ? symbolImage("exclamationmark.triangle.fill", color: color)
            : symbolImage("checkmark.circle.fill", color: color)
    }

    private func symbolImage(_ name: String, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        return UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }

    private func emojiImage(_ emoji: String, background: UIColor) -> UIImage {
        let size = CGSize(width: 44, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            background.withAlphaComponent(0.85).setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()

            let font = UIFont.systemFont(ofSize: 26)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let str = emoji as NSString
            let textSize = str.size(withAttributes: attrs)
            let rect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            str.draw(in: rect, withAttributes: attrs)
        }
    }

    private func detailText(for estimate: DrivingTimeEstimate) -> String {
        guard let mins = estimate.travelMinutes else {
            return estimate.errorMessage ?? "Unavailable"
        }

        let timeStr: String
        if mins >= 60 {
            let h = mins / 60, m = mins % 60
            timeStr = m > 0 ? "\(h)h \(m)m" : "\(h)h"
        } else {
            timeStr = "\(mins) min"
        }

        if let countdown = estimate.countdownText(now: Date()) {
            return "\(timeStr) • \(countdown)"
        }
        return "\(timeStr) • \(estimate.hasDelay ? "Delays" : "Clear")"
    }

    // MARK: - Navigation choice

    private func showNavigationChoice(for estimate: DrivingTimeEstimate) {
        let name = estimate.destination.displayName
        let coord = estimate.destination.coordinate

        let appleAction = CPAlertAction(title: "Apple Maps", style: .default) { [weak self] _ in
            self?.dismissNavigationChoice {
                self?.openAppleMaps(coordinate: coord, name: name)
            }
        }

        let googleAction = CPAlertAction(title: "Google Maps", style: .default) { [weak self] _ in
            self?.dismissNavigationChoice {
                self?.openGoogleMaps(coordinate: coord, name: name)
            }
        }

        let cancelAction = CPAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.dismissNavigationChoice()
        }

        let alert = CPAlertTemplate(
            titleVariants: ["Navigate to \(name)", name],
            actions: [appleAction, googleAction, cancelAction]
        )

        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }

    private func dismissNavigationChoice(then action: (() -> Void)? = nil) {
        interfaceController.dismissTemplate(animated: true) { _, _ in
            Task { @MainActor in
                action?()
            }
        }
    }

    private func openAppleMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let destination = MKMapItem(location: location, address: nil)
        destination.name = name
        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]

        if let carPlayScene {
            MKMapItem.openMaps(
                with: [MKMapItem.forCurrentLocation(), destination],
                launchOptions: launchOptions,
                from: carPlayScene
            ) { _ in }
            return
        }

        MKMapItem.openMaps(
            with: [MKMapItem.forCurrentLocation(), destination],
            launchOptions: launchOptions
        )
    }

    private func openGoogleMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "comgooglemaps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&daddr_name=\(encoded)&directionsmode=driving"
        guard let url = URL(string: urlStr) else {
            openAppleMaps(coordinate: coordinate, name: name)
            return
        }

        if let carPlayScene {
            carPlayScene.open(url, options: nil) { [weak self] success in
                if !success {
                    Task { @MainActor [weak self] in
                        self?.openAppleMaps(coordinate: coordinate, name: name)
                    }
                }
            }
            return
        }

        UIApplication.shared.open(url) { [weak self] success in
            if !success {
                Task { @MainActor [weak self] in
                    self?.openAppleMaps(coordinate: coordinate, name: name)
                }
            }
        }
    }
}
