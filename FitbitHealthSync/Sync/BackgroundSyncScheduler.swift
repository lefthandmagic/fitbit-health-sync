import BackgroundTasks
import Foundation

final class BackgroundSyncScheduler {
    static let refreshIdentifier = "com.praveenmurugesan.FitbitHealthSync.refresh"
    static let processingIdentifier = "com.praveenmurugesan.FitbitHealthSync.processing"

    private static var didRegister = false

    private let appModel: AppModel
    private let settingsStore: AppSettingsStore

    init(appModel: AppModel, settingsStore: AppSettingsStore) {
        self.appModel = appModel
        self.settingsStore = settingsStore
    }

    /// Must run before the app finishes launching or iOS never delivers tasks.
    func registerLaunchHandlers() {
        guard !Self.didRegister else { return }
        Self.didRegister = true

        let registeredRefresh = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshIdentifier,
            using: .main
        ) { [weak self] task in
            self?.handle(task, kind: .refresh)
        }
        let registeredProcessing = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingIdentifier,
            using: .main
        ) { [weak self] task in
            self?.handle(task, kind: .processing)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if !registeredRefresh {
                self.appModel.appendLog("Background refresh identifier failed to register.")
            }
            if !registeredProcessing {
                self.appModel.appendLog("Background processing identifier failed to register.")
            }
        }
    }

    func scheduleNext() {
        registerLaunchHandlers()
        let interval = TimeInterval(settingsStore.syncInterval.rawValue * 3600)

        let refresh = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        refresh.earliestBeginDate = Date().addingTimeInterval(interval)
        submit(refresh, label: "refresh")

        let processing = BGProcessingTaskRequest(identifier: Self.processingIdentifier)
        processing.earliestBeginDate = Date().addingTimeInterval(max(30 * 60, interval / 2))
        processing.requiresNetworkConnectivity = true
        processing.requiresExternalPower = false
        submit(processing, label: "processing")
    }

    private func submit(_ request: BGTaskRequest, label: String) {
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Task { @MainActor [weak self] in
                self?.appModel.appendLog("Background \(label) schedule failed: \(error.localizedDescription)")
            }
        }
    }

    private enum Kind {
        case refresh
        case processing
    }

    private func handle(_ task: BGTask, kind: Kind) {
        scheduleNext()

        let lock = NSLock()
        var finished = false
        let finish: (Bool) -> Void = { success in
            lock.lock()
            defer { lock.unlock() }
            guard !finished else { return }
            finished = true
            task.setTaskCompleted(success: success)
        }

        let work = Task { @MainActor [weak self] in
            guard let self else {
                finish(false)
                return
            }
            let ok = await self.appModel.runBackgroundSync(kind: kind == .processing ? "processing" : "refresh")
            finish(ok)
        }

        task.expirationHandler = {
            work.cancel()
            var shouldLog = false
            lock.lock()
            shouldLog = !finished
            lock.unlock()
            finish(false)
            guard shouldLog else { return }
            Task { @MainActor [weak self] in
                self?.appModel.markBackgroundExpired(kind: kind == .processing ? "processing" : "refresh")
            }
        }
    }
}
