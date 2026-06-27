import Combine
import EventKit
import SwiftUI
import UIKit

private enum DrivingLoadState {
    case idle
    case loading(previous: [DrivingTimeEstimate]?)
    case loaded([DrivingTimeEstimate])
    case failed(String)

    var estimates: [DrivingTimeEstimate]? {
        if case .loaded(let results) = self { return results }
        if case .loading(let previous) = self { return previous }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

struct DrivingTimesView: View {
    @Environment(DrivingDestinationStore.self) private var store
    @AppStorage("drivingProvider") private var drivingProviderRaw = DrivingProvider.apple.rawValue
    @AppStorage("googleMapsApiKey") private var googleMapsApiKey = ""

    @State private var loadState: DrivingLoadState = .idle
    @State private var lastCheckedAt: Date?
    @State private var showAdd = false
    @State private var editingDestination: DrivingDestination?
    @State private var swipedDestinationID: DrivingDestination.ID?
    @State private var now = Date()
    @State private var calendarDestinations: [DrivingDestination] = []
    @State private var calendarAuthStatus: EKAuthorizationStatus = CalendarDestinationService.shared.authorizationStatus

    private let countdownTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let calendarChangedPublisher = NotificationCenter.default.publisher(for: .EKEventStoreChanged)
    private static let autoRefreshInterval: Duration = .seconds(60)

    private var provider: DrivingProvider {
        DrivingProvider(rawValue: drivingProviderRaw) ?? .apple
    }

    private var poweredByText: String {
        provider == .google ? "Powered by Google Maps" : "Powered by Apple Maps"
    }

    private var isCalendarAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return calendarAuthStatus == .fullAccess || calendarAuthStatus == .authorized
        }
        return calendarAuthStatus == .authorized
    }

    private var combinedDestinations: [DrivingDestination] {
        calendarDestinations + store.all
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                refreshStatusCard
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                contentArea
                    .padding()
            }
        }
        .navigationTitle("Driving Times")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        Task { await fetchTimes() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(loadState.isLoading)

                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
        }
        .refreshable { await fetchTimes() }
        .sheet(isPresented: $showAdd) {
            AddDrivingDestinationView()
                .environment(store)
        }
        .sheet(item: $editingDestination) { destination in
            EditDrivingDestinationView(destination: destination)
                .environment(store)
        }
        .onReceive(countdownTimer) { tick in now = tick }
        .onReceive(calendarChangedPublisher) { _ in
            Task { await refreshCalendarAndTimes() }
        }
        .task {
            await loadCalendarDestinations()
            await fetchTimes()
        }
        .task(id: "autoRefresh") {
            await runAutoRefreshLoop()
        }
        .onChange(of: store.all.count) { _, _ in
            Task { await fetchTimes() }
        }
        .onChange(of: store.all) { _, newAll in
            refreshDestinationMetadata(from: newAll)
        }
    }

    // MARK: - Live chip

    @ViewBuilder
    private var refreshStatusCard: some View {
        HStack(spacing: 10) {
            if loadState.isLoading {
                ProgressView()
                    .scaleEffect(0.75)
                    .frame(width: 16, height: 16)
                Text("Updating…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Circle()
                    .fill(lastCheckedAt != nil ? Color.green : Color(.systemGray3))
                    .frame(width: 8, height: 8)
                Text(lastCheckedAt != nil ? "Live" : "Not yet refreshed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(lastCheckedAt != nil ? Color(red: 0.10, green: 0.50, blue: 0.20) : .secondary)
                if let lastCheckedAt {
                    Text("· updated \(lastCheckedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(provider == .google ? "Google Maps" : "Apple Maps")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            calendarBanner

            if combinedDestinations.isEmpty {
                emptyState
            } else {
                destinationsList
            }
        }
    }

    @ViewBuilder
    private var calendarBanner: some View {
        switch calendarAuthStatus {
        case .notDetermined:
            calendarPromptCard
        case .denied, .restricted:
            calendarDeniedCard
        default:
            EmptyView()
        }
    }

    private var calendarPromptCard: some View {
        Button {
            Task {
                _ = await CalendarDestinationService.shared.requestAccess()
                calendarAuthStatus = CalendarDestinationService.shared.authorizationStatus
                await refreshCalendarAndTimes()
            }
        } label: {
            HStack(spacing: 12) {
                Text("📅")
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.88, green: 0.90, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add calendar events")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Show today's events with a location as destinations.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(red: 0.94, green: 0.94, blue: 1.0))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(red: 0.72, green: 0.72, blue: 0.95), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var calendarDeniedCard: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Text("⚠️")
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(Color(red: 1.0, green: 0.94, blue: 0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar access disabled")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Enable in Settings to see today's events as destinations.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(red: 1.0, green: 0.96, blue: 0.90))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(red: 0.95, green: 0.78, blue: 0.60), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No Destinations Yet")
                    .font(.system(size: 18, weight: .bold))
                Text("Tap + to add your first destination and see live driving times from your current location.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAdd = true
            } label: {
                Label("Add Destination", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var destinationsList: some View {
        VStack(alignment: .trailing, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                switch loadState {
                case .idle:
                    loadingPlaceholder.padding()

                case .loading:
                    if let estimates = loadState.estimates {
                        estimatesView(orderedEstimates(estimates))
                    } else {
                        loadingPlaceholder.padding()
                    }

                case .loaded(let estimates):
                    estimatesView(orderedEstimates(estimates))

                case .failed(let message):
                    errorView(message: message).padding()
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
            }

        }
    }

    private func orderedEstimates(_ estimates: [DrivingTimeEstimate]) -> [DrivingTimeEstimate] {
        let calendar = estimates.filter { $0.destination.isCalendarSourced }
        let saved = estimates.filter { !$0.destination.isCalendarSourced }
        return calendar + saved
    }

    @ViewBuilder
    private func estimatesView(_ estimates: [DrivingTimeEstimate]) -> some View {
        ForEach(Array(estimates.enumerated()), id: \.element.id) { index, estimate in
            SwipeableDrivingRow(
                estimate: estimate,
                provider: provider,
                now: now,
                allowSwipeActions: !estimate.destination.isCalendarSourced,
                isOpen: Binding(
                    get: { swipedDestinationID == estimate.destination.id },
                    set: { swipedDestinationID = $0 ? estimate.destination.id : nil }
                )
            ) {
                editingDestination = estimate.destination
            } onDelete: {
                deleteDestination(estimate.destination)
            }

            if index < estimates.count - 1 {
                Rectangle()
                    .fill(Color(.separator).opacity(0.4))
                    .frame(height: 0.5)
                    .padding(.leading, 70)
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 16) {
            ForEach(combinedDestinations) { _ in
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 120, height: 18)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 180, height: 13)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 60, height: 28)
                }
                .redacted(reason: .placeholder)
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    @MainActor
    private func fetchTimes() async {
        guard !loadState.isLoading else { return }

        let previousEstimates = loadState.estimates
        let destinations = combinedDestinations
        withAnimation { loadState = .loading(previous: previousEstimates) }

        do {
            let results = try await DrivingTimeService.shared.fetchDrivingTimes(
                provider: provider,
                googleApiKey: googleMapsApiKey,
                destinations: destinations
            )

            if Task.isCancelled, let previousEstimates {
                withAnimation { loadState = .loaded(previousEstimates) }
                return
            }

            let cancelledResults = !results.isEmpty
                && results.allSatisfy { $0.errorMessage == "Route lookup cancelled." }
            if cancelledResults, let previousEstimates {
                withAnimation { loadState = .loaded(previousEstimates) }
                return
            }

            withAnimation { loadState = .loaded(results) }
            lastCheckedAt = Date()
        } catch {
            if let previousEstimates {
                withAnimation { loadState = .loaded(previousEstimates) }
            } else {
                withAnimation { loadState = .failed(error.localizedDescription) }
            }
        }
    }

    private func runAutoRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.autoRefreshInterval)
            guard !Task.isCancelled else { return }
            await loadCalendarDestinations()
            await fetchTimes()
        }
    }

    @MainActor
    private func loadCalendarDestinations() async {
        calendarAuthStatus = CalendarDestinationService.shared.authorizationStatus
        guard isCalendarAuthorized else {
            if !calendarDestinations.isEmpty { calendarDestinations = [] }
            return
        }
        let fetched = await CalendarDestinationService.shared.fetchUpcomingTodayDestinations()
        if fetched != calendarDestinations {
            calendarDestinations = fetched
        }
    }

    @MainActor
    private func refreshCalendarAndTimes() async {
        await loadCalendarDestinations()
        await fetchTimes()
    }

    private func deleteDestination(_ destination: DrivingDestination) {
        if let index = store.all.firstIndex(where: { $0.id == destination.id }) {
            store.delete(offsets: IndexSet(integer: index))
        }
    }

    /// Patches destination metadata (icon, title, arrival time) inside the current
    /// load state without discarding route times — so edits show instantly.
    private func refreshDestinationMetadata(from updatedDestinations: [DrivingDestination]) {
        guard case .loaded(let estimates) = loadState else { return }
        let patched = estimates.map { estimate -> DrivingTimeEstimate in
            guard !estimate.destination.isCalendarSourced,
                  let fresh = updatedDestinations.first(where: { $0.id == estimate.destination.id })
            else { return estimate }
            return DrivingTimeEstimate(
                destination: fresh,
                travelMinutes: estimate.travelMinutes,
                delayMinutes: estimate.delayMinutes,
                advisory: estimate.advisory,
                hasDelay: estimate.hasDelay,
                errorMessage: estimate.errorMessage
            )
        }
        loadState = .loaded(patched)
    }
}

// MARK: - Swipeable Row

private struct SwipeableDrivingRow: View {
    let estimate: DrivingTimeEstimate
    let provider: DrivingProvider
    let now: Date
    let allowSwipeActions: Bool
    @Binding var isOpen: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @GestureState private var dragTranslation: CGFloat = 0
    private let actionWidth: CGFloat = 152

    private var currentOffset: CGFloat {
        guard allowSwipeActions else { return 0 }
        let baseOffset = isOpen ? -actionWidth : 0
        return min(0, max(-actionWidth, baseOffset + dragTranslation))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if allowSwipeActions {
                actionButtons
                    .opacity(currentOffset < -8 ? 1 : 0)
                    .allowsHitTesting(isOpen)
            }

            destinationRow
        }
        .clipped()
        .animation(.snappy(duration: 0.2), value: isOpen)
    }

    @ViewBuilder
    private var destinationRow: some View {
        let base = DrivingDestinationRowView(estimate: estimate, provider: provider, now: now)
            .background(Color(.secondarySystemGroupedBackground))
            .offset(x: currentOffset)

        if allowSwipeActions {
            base.gesture(swipeGesture)
        } else {
            base
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { isOpen = false }
                onEdit()
            } label: {
                swipeActionLabel(title: "Edit", systemImage: "pencil")
            }
            .buttonStyle(.plain)
            .frame(width: actionWidth / 2)
            .background(AppTheme.info)

            Button(role: .destructive) {
                withAnimation(.snappy(duration: 0.2)) { isOpen = false }
                onDelete()
            } label: {
                swipeActionLabel(title: "Delete", systemImage: "trash")
            }
            .buttonStyle(.plain)
            .frame(width: actionWidth / 2)
            .background(AppTheme.danger)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func swipeActionLabel(title: String, systemImage: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage).font(.system(size: 18, weight: .bold))
            Text(title).font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let baseOffset = isOpen ? -actionWidth : 0
                let finalOffset = min(0, max(-actionWidth, baseOffset + value.translation.width))
                let shouldOpen = value.predictedEndTranslation.width < -actionWidth / 2
                    || value.translation.width < -actionWidth / 3
                let shouldClose = value.predictedEndTranslation.width > actionWidth / 3
                    || value.translation.width > actionWidth / 4

                if shouldOpen {
                    isOpen = true
                } else if shouldClose {
                    isOpen = false
                } else {
                    isOpen = finalOffset < -actionWidth / 2
                }
            }
    }
}
