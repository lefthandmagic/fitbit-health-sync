import Foundation

final class FitbitAPIClient: HealthDataClient {
    private let authManager: FitbitAuthManager
    private let settingsStore: AppSettingsStore
    private let decoder = JSONDecoder()

    init(authManager: FitbitAuthManager, settingsStore: AppSettingsStore) {
        self.authManager = authManager
        self.settingsStore = settingsStore
    }

    func fetchWeightLogs(start: Date, end: Date) async throws -> [WeightLog] {
        try await rawWeightLogs(start: start, end: end).map { item in
            WeightLog(
                id: "\(item.logId)",
                date: Self.parseDateTime(date: item.date, time: item.time),
                kilograms: item.weight,
                fatPercent: item.fat
            )
        }
    }

    func fetchBodyFatLogs(start: Date, end: Date) async throws -> [WeightLog] {
        try await fetchWeightLogs(start: start, end: end).filter { $0.fatPercent != nil }
    }

    func fetchDailySteps(start: Date, end: Date) async throws -> [DailyMetric] {
        struct Response: Decodable {
            let values: [FitbitDailyValue]
            enum CodingKeys: String, CodingKey { case values = "activities-steps" }
        }
        let path = "/1/user/-/activities/steps/date/\(DateFormatters.dayString(start))/\(DateFormatters.dayString(end)).json"
        let response: Response = try await request(path: path)
        return response.values.compactMap { item in
            guard let value = Double(item.value) else { return nil }
            return DailyMetric(dayStart: DateFormatters.parseDay(item.dateTime), value: value)
        }
    }

    func fetchDailyActiveEnergy(start: Date, end: Date) async throws -> [DailyMetric] {
        struct Response: Decodable {
            let values: [FitbitDailyValue]
            enum CodingKeys: String, CodingKey { case values = "activities-calories" }
        }
        let path = "/1/user/-/activities/calories/date/\(DateFormatters.dayString(start))/\(DateFormatters.dayString(end)).json"
        let response: Response = try await request(path: path)
        return response.values.compactMap { item in
            guard let value = Double(item.value) else { return nil }
            return DailyMetric(dayStart: DateFormatters.parseDay(item.dateTime), value: value)
        }
    }

    func fetchDailyRestingHeartRate(start: Date, end: Date) async throws -> [DailyMetric] {
        var out: [DailyMetric] = []
        let cal = Calendar.current
        var day = cal.startOfDay(for: start)
        let last = cal.startOfDay(for: end)

        while day <= last {
            struct DayResponse: Decodable {
                let activitiesHeart: [Heart]
                struct Heart: Decodable {
                    let dateTime: String
                    let value: HeartValue
                    struct HeartValue: Decodable {
                        let restingHeartRate: Int?
                    }
                }
                enum CodingKeys: String, CodingKey { case activitiesHeart = "activities-heart" }
            }
            let path = "/1/user/-/activities/heart/date/\(DateFormatters.dayString(day))/1d.json"
            let response: DayResponse = try await request(path: path)
            if let item = response.activitiesHeart.first,
               let rhr = item.value.restingHeartRate {
                out.append(DailyMetric(dayStart: DateFormatters.parseDay(item.dateTime), value: Double(rhr)))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return out
    }

    func fetchSleepLogs(start: Date, end: Date) async throws -> [SleepLog] {
        struct Response: Decodable { let sleep: [FitbitSleepLog] }
        let path = "/1.2/user/-/sleep/date/\(DateFormatters.dayString(start))/\(DateFormatters.dayString(end)).json"
        let response: Response = try await request(path: path)
        return response.sleep.compactMap { item in
            guard let startText = item.startTime,
                  let endText = item.endTime,
                  let sleepStart = SyncEngine.parseSleepDate(startText),
                  let sleepEnd = SyncEngine.parseSleepDate(endText) else { return nil }
            return SleepLog(
                id: "\(item.logId ?? Int64.random(in: 0...9_999_999))",
                start: sleepStart,
                end: sleepEnd
            )
        }
    }

    private func rawWeightLogs(start: Date, end: Date) async throws -> [FitbitWeightLog] {
        struct Response: Decodable { let weight: [FitbitWeightLog] }
        let path = "/1/user/-/body/log/weight/date/\(DateFormatters.dayString(start))/\(DateFormatters.dayString(end)).json"
        let response: Response = try await request(path: path)
        return response.weight
    }

    private func request<T: Decodable>(path: String) async throws -> T {
        let clientID = settingsStore.fitbitClientID
        let accessToken = try await authManager.validAccessToken(clientID: clientID)
        var request = URLRequest(url: URL(string: "https://api.fitbit.com\(path)")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "FitbitAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fitbit API call failed: \(path)"])
        }
        return try decoder.decode(T.self, from: data)
    }

    private static func parseDateTime(date: String, time: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: "\(date) \(time)") ?? DateFormatters.parseDay(date)
    }
}
