import SwiftUI
import UIKit

@main
struct FitbitHealthSyncApp: App {
    @StateObject private var model = AppModel()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onAppear {
                    model.backgroundScheduler.register()
                    model.backgroundScheduler.scheduleNext()
                }
        }
    }

    private func configureAppearance() {
        // Use explicit opaque bar backgrounds to prevent black safe-area
        // fallback when bars render outside SwiftUI content.
        let navBar = UINavigationBarAppearance()
        navBar.configureWithOpaqueBackground()
        navBar.backgroundColor = UIColor.systemGroupedBackground
        navBar.shadowColor = .clear
        navBar.titleTextAttributes = [.foregroundColor: UIColor.label]
        navBar.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navBar
        UINavigationBar.appearance().compactAppearance = navBar
        UINavigationBar.appearance().scrollEdgeAppearance = navBar

        // Tab bar: explicit background to avoid edge artifacts on newer devices.
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }
}
