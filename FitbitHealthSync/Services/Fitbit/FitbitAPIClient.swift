import Foundation

final class FitbitAPIClient {
    private let authManager: FitbitAuthManager
    private let settingsStore: AppSettingsStore
    private let decoder = JSONDecoder()

    init(authManager: FitbitAuthManager, settingsStore: AppSettingsStore) {
        self.authManager = authManager
        self.settingsStore = settingsStore
    }

    func fetchWeightLogs(start: Date, end: Date) async throws -> [FitbitWeightLog] {
        struct Response: Decodable { let weight: [FitbitWeightLog] }
        let path = "/1/user/-/body/log/weight/date/\(date(start))/\(date(end)).json"
        let response: Response = try await request(path: path)
        return response.weight
    }

    func fetchDailySteps(start: Date, end: Date) async throws -> [FitbitDailyValue] {
        struct Response: Decodable {
            let values: [FitbitDailyValue]
            enum CodingKeys: String, CodingKey { case values = "activities-steps" }
        }
        let path = "/1/user/-/activities/steps/date/\(date(start))/\(date(end)).json"
        let response: Response = try await request(path: path)
        return response.values
    }

    func fetchDailyCalories(start: Date, end: Date) async throws -> [FitbitDailyValue] {
        struct Response: Decodable {
            let values: [FitbitDailyValue]
            enum CodingKeys: String, CodingKey { case values = "activities-calories" }
        }
        let path = "/1/user/-/activities/calories/date/\(date(start))/\(date(end)).json"
        let response: Response = try await request(path: path)
        return response.values
    }

    func fetchDailyRestingHeartRate(start: Date, end: Date) async throws -> [FitbitDailyValue] {
        var out: [FitbitDailyValue] = []
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
            let path = "/1/user/-/activities/heart/date/\(date(day))/1d.json"
            let response: DayResponse = try await request(path: path)
            if let item = response.activitiesHeart.first,
               let rhr = item.value.restingHeartRate {
                out.append(FitbitDailyValue(dateTime: item.dateTime, value: "\(rhr)"))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return out
    }

    func fetchSleepLogs(start: Date, end: Date) async throws -> [FitbitSleepLog] {
        struct Response: Decodable { let sleep: [FitbitSleepLog] }
        let path = "/1.2/user/-/sleep/date/\(date(start))/\(date(end)).json"
        let response: Response = try await request(path: path)
        return response.sleep
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

    private func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
