import SwiftUI

@main
struct PapaDrivingTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let store = DrivingDestinationStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
