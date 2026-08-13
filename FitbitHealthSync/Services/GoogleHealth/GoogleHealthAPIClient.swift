import Foundation

final class GoogleHealthAPIClient: HealthDataClient {
    private let authManager: GoogleAuthManager
    private let decoder = JSONDecoder()
    private let iso = ISO8601DateFormatter()

    init(authManager: GoogleAuthManager) {
        self.authManager = authManager
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func fetchWeightLogs(start: Date, end: Date) async throws -> [WeightLog] {
        let points: [GoogleDataPoint] = try await listAll(
            dataType: "weight",
            filter: #"weight.sample_time.physical_time >= "\#(rfc3339(start))" AND weight.sample_time.physical_time < "\#(rfc3339(end))""#
        )
        return points.compactMap { point in
            guard let weight = point.weight, let grams = weight.weightGrams else { return nil }
            let date = parsePhysical(weight.sampleTime?.physicalTime) ?? Date()
            return WeightLog(
                id: point.idSuffix ?? UUID().uuidString,
                date: date,
                kilograms: grams / 1000.0,
                fatPercent: nil
            )
        }
    }

    func fetchDailySteps(start: Date, end: Date) async throws -> [DailyMetric] {
        try await dailyRollUp(dataType: "steps", start: start, end: end) { rollup, day in
            guard let sum = rollup.steps?.countSum, let value = Double(sum) else { return nil }
            return DailyMetric(dayStart: day, value: value)
        }
    }

    func fetchDailyActiveEnergy(start: Date, end: Date) async throws -> [DailyMetric] {
        try await dailyRollUp(dataType: "active-energy-burned", start: start, end: end) { rollup, day in
            guard let kcal = rollup.activeEnergyBurned?.kcalSum else { return nil }
            return DailyMetric(dayStart: day, value: kcal)
        }
    }

    func fetchDailyRestingHeartRate(start: Date, end: Date) async throws -> [DailyMetric] {
        let points: [GoogleDataPoint] = try await listAll(
            dataType: "daily-resting-heart-rate",
            filter: #"daily_resting_heart_rate.date >= "\#(DateFormatters.dayString(start))" AND daily_resting_heart_rate.date <= "\#(DateFormatters.dayString(end))""#
        )
        return points.compactMap { point in
            guard let rhr = point.dailyRestingHeartRate,
                  let bpmText = rhr.beatsPerMinute,
                  let bpm = Double(bpmText),
                  let date = rhr.date?.dateValue else { return nil }
            return DailyMetric(dayStart: date, value: bpm)
        }
    }

    func fetchSleepLogs(start: Date, end: Date) async throws -> [SleepLog] {
        let points: [GoogleDataPoint] = try await listAll(
            dataType: "sleep",
            filter: #"sleep.interval.start_time >= "\#(rfc3339(start))" AND sleep.interval.start_time < "\#(rfc3339(end))""#
        )
        return points.compactMap { point in
            guard let sleep = point.sleep,
                  let startText = sleep.interval?.startTime,
                  let endText = sleep.interval?.endTime,
                  let sleepStart = parsePhysical(startText),
                  let sleepEnd = parsePhysical(endText) else { return nil }
            return SleepLog(
                id: point.idSuffix ?? UUID().uuidString,
                start: sleepStart,
                end: sleepEnd
            )
        }
    }

    func fetchBodyFatLogs(start: Date, end: Date) async throws -> [WeightLog] {
        let points: [GoogleDataPoint] = try await listAll(
            dataType: "body-fat",
            filter: #"body_fat.sample_time.physical_time >= "\#(rfc3339(start))" AND body_fat.sample_time.physical_time < "\#(rfc3339(end))""#
        )
        return points.compactMap { point in
            guard let fat = point.bodyFat, let percent = fat.percentage else { return nil }
            let date = parsePhysical(fat.sampleTime?.physicalTime) ?? Date()
            return WeightLog(
                id: point.idSuffix ?? UUID().uuidString,
                date: date,
                kilograms: 0,
                fatPercent: percent
            )
        }
    }

    // MARK: - HTTP

    private func listAll(dataType: String, filter: String) async throws -> [GoogleDataPoint] {
        var out: [GoogleDataPoint] = []
        var pageToken: String?
        repeat {
            var items: [URLQueryItem] = [
                URLQueryItem(name: "filter", value: filter),
                URLQueryItem(name: "pageSize", value: dataType == "sleep" ? "25" : "1000")
            ]
            if let pageToken {
                items.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            var components = URLComponents(string: "\(GoogleHealthConfig.apiBase)/users/me/dataTypes/\(dataType)/dataPoints")!
            components.queryItems = items
            let response: ListResponse = try await request(url: components.url!, method: "GET")
            out.append(contentsOf: response.dataPoints ?? [])
            pageToken = response.nextPageToken
        } while pageToken != nil && !(pageToken ?? "").isEmpty
        return out
    }

    private func dailyRollUp(
        dataType: String,
        start: Date,
        end: Date,
        map: (RollupDataPoint, Date) -> DailyMetric?
    ) async throws -> [DailyMetric] {
        let cal = Calendar.current
        var cursor = cal.startOfDay(for: start)
        let last = cal.startOfDay(for: end)
        var out: [DailyMetric] = []

        while cursor <= last {
            let windowEnd = min(last, cal.date(byAdding: .day, value: 13, to: cursor) ?? last)
            let body = DailyRollUpRequest(
                range: CivilRange(start: CivilDateTime(from: cursor, endOfDay: false), end: CivilDateTime(from: windowEnd, endOfDay: true)),
                windowSizeDays: 1
            )
            let url = URL(string: "\(GoogleHealthConfig.apiBase)/users/me/dataTypes/\(dataType)/dataPoints:dailyRollUp")!
            let response: DailyRollUpResponse = try await request(url: url, method: "POST", jsonBody: body)
            for point in response.rollupDataPoints ?? [] {
                guard let day = point.civilStartTime?.date?.dateValue else { continue }
                if let metric = map(point, day) {
                    out.append(metric)
                }
            }
            guard let next = cal.date(byAdding: .day, value: 14, to: cursor) else { break }
            cursor = next
        }
        return out
    }

    private func request<T: Decodable, B: Encodable>(url: URL, method: String, jsonBody: B) async throws -> T {
        try await request(url: url, method: method, bodyData: JSONEncoder().encode(jsonBody))
    }

    private func request<T: Decodable>(url: URL, method: String, bodyData: Data? = nil) async throws -> T {
        let token = try await authManager.validAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bodyData {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "GoogleHealthAPI",
                code: (response as? HTTPURLResponse)?.statusCode ?? 1,
                userInfo: [NSLocalizedDescriptionKey: "Google Health API failed: \(url.lastPathComponent) \(snippet.prefix(180))"]
            )
        }
        if data.isEmpty, let empty = try? decoder.decode(T.self, from: Data("{}".utf8)) {
            return empty
        }
        return try decoder.decode(T.self, from: data)
    }

    private func rfc3339(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func parsePhysical(_ text: String?) -> Date? {
        guard let text else { return nil }
        if let date = iso.date(from: text) { return date }
        let fallback = ISO8601DateFormatter()
        return fallback.date(from: text)
    }
}

// MARK: - Wire models

private struct ListResponse: Decodable {
    let dataPoints: [GoogleDataPoint]?
    let nextPageToken: String?
}

private struct GoogleDataPoint: Decodable {
    let name: String?
    let weight: WeightPayload?
    let bodyFat: BodyFatPayload?
    let sleep: SleepPayload?
    let dailyRestingHeartRate: DailyRHRPayload?

    var idSuffix: String? {
        name?.split(separator: "/").last.map(String.init)
    }
}

private struct WeightPayload: Decodable {
    let sampleTime: SampleTime?
    let weightGrams: Double?
}

private struct BodyFatPayload: Decodable {
    let sampleTime: SampleTime?
    let percentage: Double?
}

private struct SampleTime: Decodable {
    let physicalTime: String?
}

private struct SleepPayload: Decodable {
    let interval: IntervalPayload?
}

private struct IntervalPayload: Decodable {
    let startTime: String?
    let endTime: String?
}

private struct DailyRHRPayload: Decodable {
    let date: CivilDate?
    let beatsPerMinute: String?
}

private struct DailyRollUpRequest: Encodable {
    let range: CivilRange
    let windowSizeDays: Int
}

private struct DailyRollUpResponse: Decodable {
    let rollupDataPoints: [RollupDataPoint]?
}

private struct RollupDataPoint: Decodable {
    let civilStartTime: CivilDateTime?
    let steps: StepsRollup?
    let activeEnergyBurned: EnergyRollup?
}

private struct StepsRollup: Decodable {
    let countSum: String?
}

private struct EnergyRollup: Decodable {
    let kcalSum: Double?
}

private struct CivilRange: Encodable {
    let start: CivilDateTime
    let end: CivilDateTime
}

private struct CivilDateTime: Codable {
    let date: CivilDate
    let time: CivilTime

    init(from day: Date, endOfDay: Bool) {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: day)
        date = CivilDate(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
        time = endOfDay ? CivilTime(hours: 23, minutes: 59, seconds: 59, nanos: 0) : CivilTime(hours: 0, minutes: 0, seconds: 0, nanos: 0)
    }
}

private struct CivilDate: Codable {
    let year: Int?
    let month: Int?
    let day: Int?

    var dateValue: Date? {
        guard let year, let month, let day else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar.current.date(from: comps)
    }
}

private struct CivilTime: Codable {
    let hours: Int?
    let minutes: Int?
    let seconds: Int?
    let nanos: Int?
}
