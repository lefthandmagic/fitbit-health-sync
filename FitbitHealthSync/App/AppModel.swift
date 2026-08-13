import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var isConnected = false
    @Published var isSyncing = false
    @Published var lastSyncText = "Never"
    @Published var logs: [String] = []
    @Published var authProvider: HealthAuthProvider?
    @Published var needsGoogleReconnect = false

    let settingsStore: AppSettingsStore
    let stateStore: SyncStateStore
    let keychainStore: KeychainStore

    private(set) lazy var authManager = FitbitAuthManager(keychain: keychainStore)
    private(set) lazy var googleAuth = GoogleAuthManager(keychain: keychainStore)
    private(set) lazy var fitbitClient = FitbitAPIClient(authManager: authManager, settingsStore: settingsStore)
    private(set) lazy var googleClient = GoogleHealthAPIClient(authManager: googleAuth)
    private(set) lazy var healthKit = HealthKitManager()
    private(set) lazy var backgroundScheduler = BackgroundSyncScheduler(appModel: self, settingsStore: settingsStore)

    /// Fitbit Web API is turned down September 2026.
    static let fitbitSunset = FitbitSunset.date

    init(
        settingsStore: AppSettingsStore = AppSettingsStore(),
        stateStore: SyncStateStore = SyncStateStore(),
        keychainStore: KeychainStore = KeychainStore()
    ) {
        self.settingsStore = settingsStore
        self.stateStore = stateStore
        self.keychainStore = keychainStore
        refreshAuthState()
        refreshLastSyncText()
    }

    var connectionTitle: String {
        switch authProvider {
        case .google: return "Connected to Google Health"
        case .fitbit: return "Connected to Fitbit (legacy)"
        case nil: return "Not Connected"
        }
    }

    var connectionSubtitle: String {
        switch authProvider {
        case .google: return "Auto-sync Google Health data to Apple Health"
        case .fitbit:
            return GoogleHealthConfig.isConfigured
                ? FitbitSunset.subtitle()
                : "Auto-sync Fitbit data to Apple Health"
        case nil: return "Tap below to connect your account"
        }
    }

    var fitbitSunsetBanner: String? {
        guard needsGoogleReconnect else { return nil }
        return FitbitSunset.banner()
    }

    func refreshAuthState() {
        if googleAuth.tokenSet != nil {
            authProvider = .google
            isConnected = true
            needsGoogleReconnect = false
        } else if authManager.tokenSet != nil {
            authProvider = .fitbit
            isConnected = true
            needsGoogleReconnect = GoogleHealthConfig.isConfigured
        } else {
            authProvider = nil
            isConnected = false
            needsGoogleReconnect = false
        }
    }

    func connectFitbit() async {
        do {
            guard !settingsStore.fitbitClientID.isEmpty else {
                appendLog("Set Fitbit Client ID in Settings first.")
                return
            }
            _ = try await authManager.authorize(clientID: settingsStore.fitbitClientID)
            keychainStore.set(HealthAuthProvider.fitbit.rawValue, for: .oauthProvider)
            refreshAuthState()
            appendLog("Fitbit connected.")
            backgroundScheduler.scheduleNext()
        } catch {
            appendLog("Connect failed: \(error.localizedDescription)")
        }
    }

    func connectGoogle() async {
        do {
            _ = try await googleAuth.authorize()
            authManager.clearTokens()
            refreshAuthState()
            appendLog("Google Health connected. Legacy Fitbit token cleared.")
            backgroundScheduler.scheduleNext()
        } catch {
            appendLog("Google connect failed: \(error.localizedDescription)")
        }
    }

    func disconnect() {
        authManager.clearTokens()
        googleAuth.clearTokens()
        keychainStore.set("", for: .oauthProvider)
        refreshAuthState()
        appendLog("Disconnected.")
    }

    @discardableResult
    func syncNow(trigger: String = "manual") async throws -> SyncRunResult {
        if isSyncing { throw NSError(domain: "Sync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sync already in progress"]) }
        isSyncing = true
        defer { isSyncing = false }
        appendLog("Starting \(trigger) sync...")
        try await healthKit.requestAuthorization(for: settingsStore.enabledMetrics)
        let client: HealthDataClient
        let prefix: String
        switch authProvider {
        case .google:
            client = googleClient
            prefix = "google"
        case .fitbit, nil:
            client = fitbitClient
            prefix = "fitbit"
        }
        let engine = SyncEngine(client: client, healthKit: healthKit, stateStore: stateStore, idPrefix: prefix)
        let result = try await engine.run(metrics: settingsStore.enabledMetrics)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        lastSyncText = formatter.string(from: result.finishedAt)
        persistLastSync(result.finishedAt)
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

    private func persistLastSync(_ date: Date) {
        UserDefaults.standard.set(ISO8601DateFormatter().string(from: date), forKey: "sync.lastFinishedAt")
    }

    private func refreshLastSyncText() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        if let raw = UserDefaults.standard.string(forKey: "sync.lastFinishedAt"),
           let date = ISO8601DateFormatter().date(from: raw) {
            lastSyncText = formatter.string(from: date)
            return
        }
        let metricDates = SyncMetric.allCases.compactMap { stateStore.lastSyncDate(for: $0) }
        if let latest = metricDates.max() {
            lastSyncText = formatter.string(from: latest)
        }
    }
}

enum FitbitSunset {
    static let date = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1))!

    static func daysRemaining(now: Date = Date(), sunset: Date = date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: now),
            to: cal.startOfDay(for: sunset)
        ).day ?? 0
    }

    static func subtitle(now: Date = Date()) -> String {
        let days = daysRemaining(now: now)
        if days < 0 { return "Fitbit API has shut down — reconnect with Google" }
        if days == 0 { return "Fitbit API shuts down today — reconnect with Google" }
        return "Reconnect with Google — Fitbit API ends in \(days) days"
    }

    static func banner(now: Date = Date()) -> String {
        let days = daysRemaining(now: now)
        if days < 0 {
            return "The Fitbit Web API has shut down. Reconnect with Google to keep syncing."
        }
        if days == 0 {
            return "The Fitbit Web API shuts down today. Reconnect with Google to keep syncing."
        }
        return "The Fitbit Web API shuts down in \(days) days (1 Sept 2026). Reconnect with Google to keep syncing."
    }
}
