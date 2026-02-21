import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var isConnected = false
    @Published var isSyncing = false
    @Published var lastSyncText = "Never"
    @Published var logs: [String] = []

    let settingsStore: AppSettingsStore
    let stateStore: SyncStateStore
    let keychainStore: KeychainStore

    private(set) lazy var authManager = FitbitAuthManager(keychain: keychainStore)
    private(set) lazy var fitbitClient = FitbitAPIClient(authManager: authManager, settingsStore: settingsStore)
    private(set) lazy var healthKit = HealthKitManager()
    private(set) lazy var syncEngine = SyncEngine(fitbit: fitbitClient, healthKit: healthKit, stateStore: stateStore)
    private(set) lazy var backgroundScheduler = BackgroundSyncScheduler(appModel: self, settingsStore: settingsStore)

    init(
        settingsStore: AppSettingsStore = AppSettingsStore(),
        stateStore: SyncStateStore = SyncStateStore(),
        keychainStore: KeychainStore = KeychainStore()
    ) {
        self.settingsStore = settingsStore
        self.stateStore = stateStore
        self.keychainStore = keychainStore
        self.isConnected = authManager.tokenSet != nil
    }

    func connectFitbit() async {
        do {
            guard !settingsStore.fitbitClientID.isEmpty else {
                appendLog("Set Fitbit Client ID in Settings first.")
                return
            }
            _ = try await authManager.authorize(clientID: settingsStore.fitbitClientID)
            isConnected = true
            appendLog("Fitbit connected.")
            backgroundScheduler.scheduleNext()
        } catch {
            appendLog("Connect failed: \(error.localizedDescription)")
        }
    }

    func disconnectFitbit() {
        authManager.clearTokens()
        isConnected = false
        appendLog("Disconnected Fitbit.")
    }

    @discardableResult
    func syncNow(trigger: String = "manual") async throws -> SyncRunResult {
        if isSyncing { throw NSError(domain: "Sync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sync already in progress"]) }
        isSyncing = true
        defer { isSyncing = false }
        appendLog("Starting \(trigger) sync...")
        try await healthKit.requestAuthorization(for: settingsStore.enabledMetrics)
        let result = try await syncEngine.run(metrics: settingsStore.enabledMetrics)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        lastSyncText = formatter.string(from: result.finishedAt)
        appendLog("Sync complete (\(result.writtenCount) samples).")
        result.details.forEach { appendLog("  \($0)") }
        backgroundScheduler.scheduleNext()
        return result
    }

    func appendLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        logs.insert("[\(timestamp)] \(message)", at: 0)
        if logs.count > 300 { logs = Array(logs.prefix(300)) }
    }

    func clearLogs() {
        logs.removeAll()
    }
}
