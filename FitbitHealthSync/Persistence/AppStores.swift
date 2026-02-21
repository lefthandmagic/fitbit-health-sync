import Foundation

final class AppSettingsStore {
    // Personal app: fixed Fitbit Client ID.
    private enum Keys {
        static let syncIntervalHours = "sync.interval.hours"
        static let enabledMetrics = "sync.enabled.metrics"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var fitbitClientID: String { "239Z9K" }

    var syncInterval: SyncIntervalHours {
        get {
            let raw = defaults.integer(forKey: Keys.syncIntervalHours)
            return SyncIntervalHours(rawValue: raw) ?? .every4
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.syncIntervalHours)
        }
    }

    var enabledMetrics: Set<SyncMetric> {
        get {
            guard let data = defaults.data(forKey: Keys.enabledMetrics),
                  let decoded = try? JSONDecoder().decode(Set<SyncMetric>.self, from: data) else {
                return [.bodyWeight, .bodyFat, .steps, .sleep, .restingHeartRate, .activeEnergy]
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.enabledMetrics)
            }
        }
    }
}

final class SyncStateStore {
    private let defaults: UserDefaults
    private let dateFormatter: ISO8601DateFormatter

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.dateFormatter = ISO8601DateFormatter()
    }

    func lastSyncDate(for metric: SyncMetric) -> Date? {
        guard let value = defaults.string(forKey: "sync.lastDate.\(metric.rawValue)") else { return nil }
        return dateFormatter.date(from: value)
    }

    func setLastSyncDate(_ date: Date, for metric: SyncMetric) {
        defaults.set(dateFormatter.string(from: date), forKey: "sync.lastDate.\(metric.rawValue)")
    }

    func hasSeen(identifier: String, metric: SyncMetric) -> Bool {
        seenIdentifiers(for: metric).contains(identifier)
    }

    func markSeen(identifier: String, metric: SyncMetric) {
        var current = seenIdentifiers(for: metric)
        current.insert(identifier)
        // Keep memory bounded.
        if current.count > 5_000 {
            current = Set(current.suffix(4_000))
        }
        defaults.set(Array(current), forKey: "sync.seen.\(metric.rawValue)")
    }

    private func seenIdentifiers(for metric: SyncMetric) -> Set<String> {
        Set(defaults.stringArray(forKey: "sync.seen.\(metric.rawValue)") ?? [])
    }
}
