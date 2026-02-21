import BackgroundTasks
import Foundation

final class BackgroundSyncScheduler {
    static var taskIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "com.praveenmurugesan.FitbitHealthSync").refresh"
    }
    private static var didRegister = false

    private let appModel: AppModel
    private let settingsStore: AppSettingsStore

    init(appModel: AppModel, settingsStore: AppSettingsStore) {
        self.appModel = appModel
        self.settingsStore = settingsStore
    }

    func register() {
        guard hasPermittedIdentifier else { return }
        guard !Self.didRegister else { return }
        Self.didRegister = true
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [weak self] task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handle(task: appRefreshTask)
        }
    }

    func scheduleNext() {
        guard hasPermittedIdentifier else {
            Task { @MainActor in
                appModel.appendLog("Background task identifier missing in Info.plist; skipping schedule.")
            }
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(TimeInterval(settingsStore.syncInterval.rawValue * 3600))
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Task { @MainActor in
                appModel.appendLog("Background schedule failed: \(error.localizedDescription)")
            }
        }
    }

    private func handle(task: BGAppRefreshTask) {
        scheduleNext()
        let operation = Task {
            do {
                _ = try await appModel.syncNow(trigger: "background")
                task.setTaskCompleted(success: true)
            } catch {
                await appModel.appendLog("Background sync failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = {
            operation.cancel()
        }
    }

    private var hasPermittedIdentifier: Bool {
        let key = "BGTaskSchedulerPermittedIdentifiers"
        let identifiers = Bundle.main.object(forInfoDictionaryKey: key) as? [String] ?? []
        return identifiers.contains(Self.taskIdentifier)
    }
}
