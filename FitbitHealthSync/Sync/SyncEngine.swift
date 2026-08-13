import Foundation

final class SyncEngine {
    private let client: HealthDataClient
    private let healthKit: HealthKitManager
    private let stateStore: SyncStateStore
    private let idPrefix: String

    init(client: HealthDataClient, healthKit: HealthKitManager, stateStore: SyncStateStore, idPrefix: String) {
        self.client = client
        self.healthKit = healthKit
        self.stateStore = stateStore
        self.idPrefix = idPrefix
    }

    func run(metrics: Set<SyncMetric>) async throws -> SyncRunResult {
        let start = Date()
        var totalWritten = 0
        var details: [String] = []
        var failures = 0

        for metric in metrics.sorted(by: { $0.rawValue < $1.rawValue }) {
            do {
                let written = try await sync(metric: metric)
                totalWritten += written
                details.append("\(metric.title): \(written)")
                stateStore.setLastSyncDate(Date(), for: metric)
            } catch {
                failures += 1
                let snippet = String(error.localizedDescription.prefix(120))
                details.append("\(metric.title): failed — \(snippet)")
            }
        }

        if failures == metrics.count, !metrics.isEmpty {
            throw NSError(
                domain: "Sync",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: details.joined(separator: "; ")]
            )
        }

        return SyncRunResult(
            startedAt: start,
            finishedAt: Date(),
            writtenCount: totalWritten,
            details: details
        )
    }

    private func sync(metric: SyncMetric) async throws -> Int {
        let now = Date()
        let defaultStart = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let rawStart = stateStore.lastSyncDate(for: metric) ?? defaultStart
        // Re-query one day back to tolerate ingestion delays around day boundaries.
        let start = Calendar.current.date(byAdding: .day, value: -1, to: rawStart) ?? rawStart
        let end = now

        switch metric {
        case .bodyWeight:
            return try await syncWeight(start: start, end: end)
        case .bodyFat:
            return try await syncBodyFat(start: start, end: end)
        case .steps:
            return try await syncSteps(start: start, end: end)
        case .restingHeartRate:
            return try await syncRestingHeartRate(start: start, end: end)
        case .activeEnergy:
            return try await syncActiveEnergy(start: start, end: end)
        case .sleep:
            return try await syncSleep(start: start, end: end)
        }
    }

    private func syncWeight(start: Date, end: Date) async throws -> Int {
        let logs = try await client.fetchWeightLogs(start: start, end: end)
        var written = 0
        for item in logs {
            let syncID = "\(idPrefix)-weight-\(item.id)"
            if !stateStore.hasSeen(identifier: syncID, metric: .bodyWeight) {
                try await healthKit.saveBodyWeight(kg: item.kilograms, date: item.date, syncID: syncID)
                stateStore.markSeen(identifier: syncID, metric: .bodyWeight)
                written += 1
            }
        }
        return written
    }

    private func syncBodyFat(start: Date, end: Date) async throws -> Int {
        let logs = try await client.fetchBodyFatLogs(start: start, end: end)
        var written = 0
        for item in logs {
            guard let fat = item.fatPercent else { continue }
            let syncID = "\(idPrefix)-fat-\(item.id)"
            if !stateStore.hasSeen(identifier: syncID, metric: .bodyFat) {
                try await healthKit.saveBodyFat(percentage: fat, date: item.date, syncID: syncID)
                stateStore.markSeen(identifier: syncID, metric: .bodyFat)
                written += 1
            }
        }
        return written
    }

    private func syncSteps(start: Date, end: Date) async throws -> Int {
        let daily = try await client.fetchDailySteps(start: start, end: end)
        var written = 0
        for item in daily {
            guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: item.dayStart) else { continue }
            let day = DateFormatters.dayString(item.dayStart)
            let syncID = "\(idPrefix)-steps-\(day)"
            if !stateStore.hasSeen(identifier: syncID, metric: .steps) {
                try await healthKit.saveSteps(item.value, start: item.dayStart, end: dayEnd, syncID: syncID)
                stateStore.markSeen(identifier: syncID, metric: .steps)
                written += 1
            }
        }
        return written
    }

    private func syncRestingHeartRate(start: Date, end: Date) async throws -> Int {
        let daily = try await client.fetchDailyRestingHeartRate(start: start, end: end)
        var written = 0
        for item in daily {
            let day = DateFormatters.dayString(item.dayStart)
            let syncID = "\(idPrefix)-rhr-\(day)"
            if !stateStore.hasSeen(identifier: syncID, metric: .restingHeartRate) {
                try await healthKit.saveRestingHeartRate(item.value, date: item.dayStart, syncID: syncID)
                stateStore.markSeen(identifier: syncID, metric: .restingHeartRate)
                written += 1
            }
        }
        return written
    }

    private func syncActiveEnergy(start: Date, end: Date) async throws -> Int {
        let daily = try await client.fetchDailyActiveEnergy(start: start, end: end)
        var written = 0
        for item in daily {
            guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: item.dayStart) else { continue }
            let day = DateFormatters.dayString(item.dayStart)
            let syncID = "\(idPrefix)-active-energy-\(day)"
            if !stateStore.hasSeen(identifier: syncID, metric: .activeEnergy) {
                try await healthKit.saveActiveEnergy(kcal: item.value, start: item.dayStart, end: dayEnd, syncID: syncID)
                stateStore.markSeen(identifier: syncID, metric: .activeEnergy)
                written += 1
            }
        }
        return written
    }

    private func syncSleep(start: Date, end: Date) async throws -> Int {
        let logs = try await client.fetchSleepLogs(start: start, end: end)
        var written = 0
        for item in logs {
            let syncID = "\(idPrefix)-sleep-\(item.id)"
            guard !stateStore.hasSeen(identifier: syncID, metric: .sleep) else { continue }
            try await healthKit.saveSleep(start: item.start, end: item.end, syncID: syncID)
            stateStore.markSeen(identifier: syncID, metric: .sleep)
            written += 1
        }
        return written
    }

    static func parseSleepDate(_ text: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: text) {
            return date
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = formatter.date(from: text) {
            return date
        }

        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: text) {
            return date
        }

        return nil
    }
}
