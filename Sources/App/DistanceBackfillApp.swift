import SwiftUI

@main
struct DistanceBackfillApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
