import Foundation

final class SyncEngine {
    private let fitbit: FitbitAPIClient
    private let healthKit: HealthKitManager
    private let stateStore: SyncStateStore

    init(fitbit: FitbitAPIClient, healthKit: HealthKitManager, stateStore: SyncStateStore) {
        self.fitbit = fitbit
        self.healthKit = healthKit
        self.stateStore = stateStore
    }

    func run(metrics: Set<SyncMetric>) async throws -> SyncRunResult {
        let start = Date()
        var totalWritten = 0
        var details: [String] = []

        for metric in metrics {
            let written = try await sync(metric: metric)
            totalWritten += written
            details.append("\(metric.title): \(written)")
            stateStore.setLastSyncDate(Date(), for: metric)
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
        let start = stateStore.lastSyncDate(for: metric) ?? defaultStart
        let end = now

        switch metric {
        case .bodyWeight, .bodyFat:
            return try await syncWeight(start: start, end: end, includeFat: metric == .bodyFat)
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

    private func syncWeight(start: Date, end: Date, includeFat: Bool) async throws -> Int {
        let logs = try await fitbit.fetchWeightLogs(start: start, end: end)
        var written = 0
        for item in logs {
            let date = parseDateTime(date: item.date, time: item.time)
            let weightSyncID = "fitbit-weight-\(item.logId)"
            if !stateStore.hasSeen(identifier: weightSyncID, metric: .bodyWeight) {
                try await healthKit.saveBodyWeight(kg: item.weight, date: date, syncID: weightSyncID)
                stateStore.markSeen(identifier: weightSyncID, metric: .bodyWeight)
                written += 1
            }
            if includeFat, let fat = item.fat {
                let fatSyncID = "fitbit-fat-\(item.logId)"
                if !stateStore.hasSeen(identifier: fatSyncID, metric: .bodyFat) {
                    try await healthKit.saveBodyFat(percentage: fat, date: date, syncID: fatSyncID)
                    stateStore.markSeen(identifier: fatSyncID, metric: .bodyFat)
                    written += 1
                }
            }
        }
        return written
    }

    private func syncSteps(start: Date, end: Date) async throws -> Int {
        let daily = try await fitbit.fetchDailySteps(start: start, end: end)
        var written = 0
        for item in daily {
            guard let count = Double(item.value) else { continue }
            let dayStart = parseDate(item.dateTime)
            guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let syncID = "fitbit-steps-\(item.dateTime)"
            if !stateStore.hasSeen(identifier: syncID, metric: .steps) {
                try await healthKit.saveSteps(count, start: dayStart, end: dayEnd, syncID: syncID)
                stateStore.markSeen(identifier: syncID, metric: .steps)
                written += 1
            }
        }
        return written
    }

    private func syncRestingHeartRate(start: Date, end: Date) async throws -> Int {
        let daily = try await fitbit.fetchDailyRestingHeartRate(start: start, end: end)
        var written = 0
        for item in daily {
            guard let bpm = Double(item.value) else { continue }
            let date = parseDate(item.dateTime)
            let syncID = "fitbit-rhr-\(item.dateTime)"
            if !stateStore.hasSeen(identifier: syncID, metric: .restingHeartRate) {
                try await healthKit.saveRestingHeartRate(bpm, date: date, syncID: syncID)
                stateStore.markSeen(identifier: syncID, metric: .restingHeartRate)
                written += 1
            }
        }
        return written
    }

    private func syncActiveEnergy(start: Date, end: Date) async throws -> Int {
        let daily = try await fitbit.fetchDailyCalories(start: start, end: end)
        var written = 0
        for item in daily {
            guard let kcal = Double(item.value) else { continue }
            let dayStart = parseDate(item.dateTime)
            guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let syncID = "fitbit-active-energy-\(item.dateTime)"
            if !stateStore.hasSeen(identifier: syncID, metric: .activeEnergy) {
                try await healthKit.saveActiveEnergy(kcal: kcal, start: dayStart, end: dayEnd, syncID: syncID)
                stateStore.markSeen(identifier: syncID, metric: .activeEnergy)
                written += 1
            }
        }
        return written
    }

    private func syncSleep(start: Date, end: Date) async throws -> Int {
        let logs = try await fitbit.fetchSleepLogs(start: start, end: end)
        var written = 0
        let formatter = ISO8601DateFormatter()
        for item in logs {
            let syncID = "fitbit-sleep-\(item.logId ?? Int64.random(in: 0...9_999_999))"
            guard !stateStore.hasSeen(identifier: syncID, metric: .sleep) else { continue }
            guard let startText = item.startTime,
                  let endText = item.endTime,
                  let sleepStart = formatter.date(from: startText),
                  let sleepEnd = formatter.date(from: endText) else {
                continue
            }
            try await healthKit.saveSleep(start: sleepStart, end: sleepEnd, syncID: syncID)
            stateStore.markSeen(identifier: syncID, metric: .sleep)
            written += 1
        }
        return written
    }

    private func parseDate(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text) ?? Date()
    }

    private func parseDateTime(date: String, time: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: "\(date) \(time)") ?? parseDate(date)
    }
}
