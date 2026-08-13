import Foundation

/// Shared read model used by both Fitbit Web API and Google Health API sync paths.
protocol HealthDataClient {
    func fetchWeightLogs(start: Date, end: Date) async throws -> [WeightLog]
    func fetchBodyFatLogs(start: Date, end: Date) async throws -> [WeightLog]
    func fetchDailySteps(start: Date, end: Date) async throws -> [DailyMetric]
    func fetchDailyActiveEnergy(start: Date, end: Date) async throws -> [DailyMetric]
    func fetchDailyRestingHeartRate(start: Date, end: Date) async throws -> [DailyMetric]
    func fetchSleepLogs(start: Date, end: Date) async throws -> [SleepLog]
}

struct WeightLog {
    let id: String
    let date: Date
    let kilograms: Double
    let fatPercent: Double?
}

struct DailyMetric {
    let dayStart: Date
    let value: Double
}

struct SleepLog {
    let id: String
    let start: Date
    let end: Date
}

enum HealthAuthProvider: String {
    case fitbit
    case google
}

enum DateFormatters {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayString(_ date: Date) -> String {
        day.string(from: date)
    }

    static func parseDay(_ text: String) -> Date {
        day.date(from: text) ?? Date()
    }
}
