import BackgroundTasks
import Foundation
import UIKit

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
                self.appModel.noteBackgroundScheduled("register failed · refresh id")
            }
            if !registeredProcessing {
                self.appModel.noteBackgroundScheduled("register failed · processing id")
            }
        }
    }

    func scheduleNext() {
        registerLaunchHandlers()
        let interval = settingsStore.syncInterval.delay

        var errors: [String] = []
        let refresh = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        refresh.earliestBeginDate = Date().addingTimeInterval(interval)
        submit(refresh, label: "refresh", errors: &errors)

        let processing = BGProcessingTaskRequest(identifier: Self.processingIdentifier)
        processing.earliestBeginDate = Date().addingTimeInterval(max(15 * 60, interval))
        processing.requiresNetworkConnectivity = true
        processing.requiresExternalPower = false
        submit(processing, label: "processing", errors: &errors)

        let scheduleErrors = errors
        Task { @MainActor [weak self] in
            guard let self else { return }
            let bar = self.appModel.backgroundRefreshStatusText
            if scheduleErrors.isEmpty {
                let mins = max(1, Int(interval / 60))
                self.appModel.noteBackgroundScheduled("\(bar) · waiting (≥\(mins)m, iOS decides)")
            } else {
                self.appModel.noteBackgroundScheduled("failed · \(scheduleErrors.joined(separator: "; "))")
            }
        }
    }

    private func submit(_ request: BGTaskRequest, label: String, errors: inout [String]) {
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            errors.append("\(label): \(error.localizedDescription)")
        }
    }

    private enum Kind {
        case refresh
        case processing
    }

    private func handle(_ task: BGTask, kind: Kind) {
        scheduleNext()

        let lock = OnceFlag()
        let finish: (Bool) -> Void = { success in
            lock.runOnce {
                task.setTaskCompleted(success: success)
            }
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
            let first = lock.runOnce {
                task.setTaskCompleted(success: false)
            }
            guard first else { return }
            Task { @MainActor [weak self] in
                self?.appModel.markBackgroundExpired(kind: kind == .processing ? "processing" : "refresh")
            }
        }
    }
}

/// Completes a BGTask at most once. iOS crashes if `setTaskCompleted` is called twice.
final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    /// Returns true if this call ran the work.
    @discardableResult
    func runOnce(_ work: () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return false }
        done = true
        work()
        return true
    }
}

enum BackgroundRefreshMessaging {
    static func statusText(_ status: UIBackgroundRefreshStatus) -> String {
        switch status {
        case .available: return "BAR on"
        case .denied: return "BAR off (Settings)"
        case .restricted: return "BAR restricted"
        @unknown default: return "BAR unknown"
        }
    }
}
