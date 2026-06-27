import Combine
import Contacts
import CoreLocation
import Foundation
import MapKit
import SwiftUI

// MARK: - Add Destination

struct AddDrivingDestinationView: View {
    @Environment(DrivingDestinationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel = DestinationSearchModel()
    @State private var customTitle = ""
    @State private var selectedIconID = DestinationIcon.default.id
    @State private var setArrivalTime = false
    @State private var arrivalTime = Date()

    var body: some View {
        NavigationStack {
            Form {
                searchSection
                if searchModel.selectedDestination != nil {
                    titleSection
                    iconSection
                    arrivalTimeSection
                    selectedSection
                }
                suggestionsSection
            }
            .navigationTitle("Add Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(searchModel.selectedDestination == nil)
                }
            }
            .onChange(of: searchModel.selectedContactName) { _, name in
                if let name, customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    customTitle = name
                }
            }
        }
    }

    private var searchSection: some View {
        Section {
            TextField("Address or contact name", text: $searchModel.query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            if searchModel.isSearching {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching…").foregroundStyle(.secondary)
                }
            }

            if let errorMessage = searchModel.errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Destination Search")
        } footer: {
            Text("Search by address or by a contact's name.")
        }
    }

    private var titleSection: some View {
        Section {
            TextField("e.g. Home, Work, Gym", text: $customTitle)
                .textInputAutocapitalization(.words)
        } header: {
            Text("Label (Optional)")
        } footer: {
            Text("Give this destination a friendly name. If empty, the address is used instead.")
        }
    }

    private var iconSection: some View {
        Section {
            IconPickerGrid(selectedID: $selectedIconID)
        } header: {
            Text("Icon")
        } footer: {
            Text("Shown on the card so you can spot this destination at a glance.")
        }
    }

    private var arrivalTimeSection: some View {
        Section {
            Toggle("Set arrival time target", isOn: $setArrivalTime)
            if setArrivalTime {
                DatePicker("Arrive by", selection: $arrivalTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Arrival Time (Optional)")
        } footer: {
            if setArrivalTime {
                Text("The app will calculate when you need to leave to arrive on time.")
            } else {
                Text("Set a daily arrival target to see a \"Leave in X min\" countdown.")
            }
        }
    }

    private var selectedSection: some View {
        Section {
            if let dest = searchModel.selectedDestination {
                DestinationPreviewRow(destination: dest.withTitle(customTitle))
            }
        } header: {
            Text("Selected Destination")
        }
    }

    private var suggestionsSection: some View {
        Section {
            if searchModel.suggestions.isEmpty {
                Text(searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines).count < 3
                     ? "Enter at least 3 characters to see suggestions."
                     : "No matching addresses or contacts found yet.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(searchModel.suggestions) { suggestion in
                    Button {
                        searchModel.select(suggestion)
                    } label: {
                        SuggestionRowLabel(suggestion: suggestion)
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            Text("Suggestions")
        }
    }

    private func save() {
        guard var destination = searchModel.selectedDestination else { return }
        let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        destination.title = trimmed.isEmpty ? nil : trimmed
        destination.icon = selectedIconID
        if setArrivalTime {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: arrivalTime)
            destination.targetArrivalHour = comps.hour
            destination.targetArrivalMinute = comps.minute
        }
        store.add(destination)
        dismiss()
    }
}

// MARK: - Edit Destination

struct EditDrivingDestinationView: View {
    @Environment(DrivingDestinationStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let destination: DrivingDestination
    @State private var editedTitle: String
    @State private var selectedIconID: String
    @State private var setArrivalTime: Bool
    @State private var arrivalTime: Date
    @State private var showAddressSearch = false
    @StateObject private var searchModel = DestinationSearchModel()

    init(destination: DrivingDestination) {
        self.destination = destination
        _editedTitle = State(initialValue: destination.title ?? "")
        _selectedIconID = State(initialValue: destination.icon)
        let hasTarget = destination.targetArrivalHour != nil
        _setArrivalTime = State(initialValue: hasTarget)
        if let hour = destination.targetArrivalHour, let minute = destination.targetArrivalMinute {
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            let date = Calendar.current.date(from: comps) ?? Date()
            _arrivalTime = State(initialValue: date)
        } else {
            _arrivalTime = State(initialValue: Date())
        }
    }

    private var resolvedDestination: DrivingDestination {
        let base = searchModel.selectedDestination ?? destination
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var hour: Int? = nil
        var minute: Int? = nil
        if setArrivalTime {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: arrivalTime)
            hour = comps.hour
            minute = comps.minute
        }
        return DrivingDestination(
            id: destination.id,
            name: base.name,
            address: base.address,
            latitude: base.latitude,
            longitude: base.longitude,
            title: trimmed.isEmpty ? nil : trimmed,
            icon: selectedIconID,
            targetArrivalHour: hour,
            targetArrivalMinute: minute
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Home, Work, Gym", text: $editedTitle)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Label (Optional)")
                }

                Section {
                    IconPickerGrid(selectedID: $selectedIconID)
                } header: {
                    Text("Icon")
                }

                Section {
                    Toggle("Set arrival time target", isOn: $setArrivalTime)
                    if setArrivalTime {
                        DatePicker("Arrive by", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Arrival Time")
                } footer: {
                    Text("Shows a \"Leave in X min\" countdown on the main screen.")
                }

                Section {
                    DestinationPreviewRow(destination: resolvedDestination)
                } header: {
                    Text("Preview")
                }

                Section {
                    if !showAddressSearch {
                        Button("Change Address") { showAddressSearch = true }
                    } else {
                        TextField("Address or contact name", text: $searchModel.query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()

                        if searchModel.isSearching {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Searching…").foregroundStyle(.secondary)
                            }
                        }

                        if let errorMessage = searchModel.errorMessage {
                            Text(errorMessage).font(.caption).foregroundStyle(.red)
                        }

                        if searchModel.selectedDestination != nil {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("New address selected").font(.subheadline)
                            }
                        }
                    }
                } header: {
                    Text("Address")
                } footer: {
                    if !showAddressSearch { Text(destination.address) }
                }

                if showAddressSearch && !searchModel.suggestions.isEmpty {
                    Section {
                        ForEach(searchModel.suggestions) { suggestion in
                            Button {
                                searchModel.select(suggestion)
                            } label: {
                                SuggestionRowLabel(suggestion: suggestion)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Suggestions")
                    }
                }
            }
            .navigationTitle("Edit Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.update(resolvedDestination)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Suggestion Row Label

private struct SuggestionRowLabel: View {
    let suggestion: DestinationSearchModel.Suggestion

    var body: some View {
        HStack(spacing: 10) {
            if suggestion.isContact {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title).foregroundStyle(.primary)
                if !suggestion.subtitle.isEmpty {
                    Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Destination Preview Row

struct DestinationPreviewRow: View {
    let destination: DrivingDestination

    private var icon: DestinationIcon { DestinationIcon.find(destination.icon) }

    var body: some View {
        HStack(spacing: 12) {
            Text(icon.emoji)
                .font(.system(size: 20))
                .frame(width: 38, height: 38)
                .background(icon.background)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.displayName).font(.body.weight(.semibold))
                Text(destination.displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let arrivalDisplay = destination.arrivalTargetDisplay {
                    Text(arrivalDisplay).font(.caption).foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Icon picker grid

struct IconPickerGrid: View {
    @Binding var selectedID: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(DestinationIcon.presets) { icon in
                Button {
                    selectedID = icon.id
                } label: {
                    Text(icon.emoji)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(selectedID == icon.id ? icon.background : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay {
                            if selectedID == icon.id {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(icon.foreground.opacity(0.5), lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.label)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - DestinationSearchModel

@MainActor
final class DestinationSearchModel: NSObject, ObservableObject {

    struct Suggestion: Identifiable {
        enum Source {
            case map(completion: MKLocalSearchCompletion)
            case contact(postalAddress: CNPostalAddress, displayName: String)
        }

        let id = UUID()
        let title: String
        let subtitle: String
        fileprivate let source: Source

        var isContact: Bool {
            if case .contact = source { return true }
            return false
        }

        fileprivate var contactDisplayName: String? {
            if case .contact(_, let name) = source { return name }
            return nil
        }
    }

    @Published var query = "" {
        didSet { handleQueryChange() }
    }
    @Published private(set) var suggestions: [Suggestion] = []
    @Published private(set) var selectedDestination: DrivingDestination?
    @Published private(set) var selectedContactName: String?
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()
    private let contactStore = CNContactStore()
    private var suppressQuerySideEffects = false
    private var contactSearchTask: Task<Void, Never>?
    private var mapSuggestions: [Suggestion] = []
    private var contactSuggestions: [Suggestion] = []

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func select(_ suggestion: Suggestion) {
        Task { await resolve(suggestion) }
    }

    private func handleQueryChange() {
        guard !suppressQuerySideEffects else { return }
        selectedDestination = nil
        selectedContactName = nil
        errorMessage = nil

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            mapSuggestions = []
            contactSuggestions = []
            suggestions = []
            isSearching = false
            contactSearchTask?.cancel()
            completer.queryFragment = ""
            return
        }

        isSearching = true
        completer.queryFragment = trimmed

        contactSearchTask?.cancel()
        let q = trimmed
        contactSearchTask = Task { await searchContacts(query: q) }
    }

    private func rebuildSuggestions() {
        suggestions = contactSuggestions + mapSuggestions
    }

    // MARK: Contact search

    private func searchContacts(query: String) async {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined {
            guard (try? await contactStore.requestAccess(for: .contacts)) == true else { return }
        } else if status != .authorized && status != .limited {
            return
        }

        guard !Task.isCancelled else { return }

        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor
        ]
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let found = (try? contactStore.unifiedContacts(matching: predicate, keysToFetch: keys)) ?? []

        guard !Task.isCancelled else { return }

        let results: [Suggestion] = found.flatMap { contact -> [Suggestion] in
            let fullName = CNContactFormatter.string(from: contact, style: .fullName)?
                .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            let orgName = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            guard let displayName = fullName ?? orgName else { return [] }
            guard !contact.postalAddresses.isEmpty else { return [] }

            let needsLabel = contact.postalAddresses.count > 1
            return contact.postalAddresses.map { labeled in
                let addr = labeled.value
                let formatted = Self.formatPostalAddress(addr)
                let subtitle: String
                if needsLabel, let raw = labeled.label, !raw.isEmpty {
                    let humanLabel = CNLabeledValue<CNPostalAddress>.localizedString(forLabel: raw)
                    subtitle = "\(humanLabel) · \(formatted)"
                } else {
                    subtitle = formatted
                }
                return Suggestion(
                    title: displayName,
                    subtitle: subtitle,
                    source: .contact(postalAddress: addr, displayName: displayName)
                )
            }
        }

        contactSuggestions = results
        rebuildSuggestions()
    }

    // MARK: Resolution

    private func resolve(_ suggestion: Suggestion) async {
        isSearching = true
        errorMessage = nil
        switch suggestion.source {
        case .map(let completion):
            await resolveMap(completion: completion, fallbackSubtitle: suggestion.subtitle)
        case .contact(let postalAddress, let displayName):
            await resolveContact(postalAddress: postalAddress, displayName: displayName)
        }
    }

    private func resolveMap(completion: MKLocalSearchCompletion, fallbackSubtitle: String) async {
        do {
            let request = MKLocalSearch.Request(completion: completion)
            request.resultTypes = [.address, .pointOfInterest]
            let response = try await Self.startSearch(request)
            guard let item = response.mapItems.first else {
                errorMessage = "The selected address could not be resolved."
                isSearching = false
                return
            }

            let location = item.location
            let resolved = DrivingDestination(
                name: item.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? completion.title,
                address: Self.formattedAddress(for: item, fallbackSubtitle: fallbackSubtitle),
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )

            suppressQuerySideEffects = true
            query = resolved.address
            suppressQuerySideEffects = false

            selectedDestination = resolved
            selectedContactName = nil
            suggestions = []
            isSearching = false
        } catch is CancellationError {
            errorMessage = "Address search was cancelled."
            isSearching = false
        } catch {
            errorMessage = error.localizedDescription
            isSearching = false
        }
    }

    private func resolveContact(postalAddress: CNPostalAddress, displayName: String) async {
        do {
            let placemarks: [CLPlacemark] = try await withCheckedThrowingContinuation { cont in
                CLGeocoder().geocodePostalAddress(postalAddress) { placemarks, error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: placemarks ?? [])
                    }
                }
            }

            guard let placemark = placemarks.first, let location = placemark.location else {
                errorMessage = "Could not resolve this contact's address to a location."
                isSearching = false
                return
            }

            let formatted = Self.formatPostalAddress(postalAddress)
            let resolved = DrivingDestination(
                name: displayName,
                address: formatted,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )

            suppressQuerySideEffects = true
            query = formatted
            suppressQuerySideEffects = false

            selectedDestination = resolved
            selectedContactName = displayName
            suggestions = []
            isSearching = false
        } catch is CancellationError {
            errorMessage = "Address search was cancelled."
            isSearching = false
        } catch {
            errorMessage = "Could not geocode address: \(error.localizedDescription)"
            isSearching = false
        }
    }

    // MARK: Helpers

    private static func formatPostalAddress(_ address: CNPostalAddress) -> String {
        CNPostalAddressFormatter.string(from: address, style: .mailingAddress)
            .components(separatedBy: "\n")
            .joined(separator: ", ")
    }

    private static func startSearch(_ request: MKLocalSearch.Request) async throws -> MKLocalSearch.Response {
        let search = MKLocalSearch(request: request)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                search.start { response, error in
                    if let response {
                        continuation.resume(returning: response)
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: LocationError.unavailable)
                    }
                }
            }
        } onCancel: {
            search.cancel()
        }
    }

    private static func formattedAddress(for item: MKMapItem, fallbackSubtitle: String) -> String {
        if let formatted = item.addressRepresentations?
            .fullAddress(includingRegion: true, singleLine: true),
           !formatted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return formatted
        }

        if let full = item.address?.fullAddress as String?,
           !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return full
        }

        if let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            return name
        }

        return fallbackSubtitle.isEmpty ? "Selected destination" : fallbackSubtitle
    }
}

extension DestinationSearchModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        mapSuggestions = completer.results.map {
            Suggestion(title: $0.title, subtitle: $0.subtitle, source: .map(completion: $0))
        }
        rebuildSuggestions()
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        mapSuggestions = []
        rebuildSuggestions()
        errorMessage = error.localizedDescription
        isSearching = false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
