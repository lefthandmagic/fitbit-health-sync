import SwiftUI
import UIKit

@main
@MainActor
struct FitbitHealthSyncApp: App {
    @StateObject private var model: AppModel

    init() {
        Self.configureAppearance()
        let model = AppModel()
        // Handlers must be registered before launch finishes — onAppear is too late.
        model.backgroundScheduler.registerLaunchHandlers()
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onAppear {
                    model.backgroundScheduler.scheduleNext()
                }
        }
    }

    private static func configureAppearance() {
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
