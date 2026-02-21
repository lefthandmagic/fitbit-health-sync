import Foundation

enum SyncMetric: String, CaseIterable, Codable, Identifiable {
    case bodyWeight
    case bodyFat
    case steps
    case sleep
    case restingHeartRate
    case activeEnergy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyWeight: return "Body Weight"
        case .bodyFat: return "Body Fat %"
        case .steps: return "Steps"
        case .sleep: return "Sleep"
        case .restingHeartRate: return "Resting Heart Rate"
        case .activeEnergy: return "Active Energy"
        }
    }

    var symbol: String {
        switch self {
        case .bodyWeight: return "scalemass.fill"
        case .bodyFat: return "percent"
        case .steps: return "figure.walk"
        case .sleep: return "bed.double.fill"
        case .restingHeartRate: return "heart.fill"
        case .activeEnergy: return "flame.fill"
        }
    }
}

enum SyncIntervalHours: Int, CaseIterable, Codable, Identifiable {
    case every2 = 2
    case every4 = 4
    case every8 = 8
    case every12 = 12

    var id: Int { rawValue }
    var title: String { "Every \(rawValue) hours" }
    var shortTitle: String { "\(rawValue)h" }
}

struct FitbitWeightLog: Codable {
    let bmi: Double?
    let date: String
    let fat: Double?
    let logId: Int64
    let source: String?
    let time: String
    let weight: Double
}

struct FitbitDailyValue: Codable {
    let dateTime: String
    let value: String
}

struct FitbitSleepLog: Codable {
    let logId: Int64?
    let startTime: String?
    let endTime: String?
    let dateOfSleep: String?
    let duration: Int?
}

struct SyncRunResult {
    let startedAt: Date
    let finishedAt: Date
    let writtenCount: Int
    let details: [String]
}
