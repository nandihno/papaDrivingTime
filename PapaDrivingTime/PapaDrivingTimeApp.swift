import SwiftUI

@main
struct PapaDrivingTimeApp: App {
    private let store = DrivingDestinationStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
