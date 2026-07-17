import SwiftUI

@main
struct GymAppApp: App {
    @StateObject private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            GymAppRootView()
                .environmentObject(store)
                .tint(AppTheme.accent)
        }
    }
}
