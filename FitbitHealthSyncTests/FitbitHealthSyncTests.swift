import XCTest
@testable import FitbitHealthSync

final class FitbitHealthSyncTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private var testSuiteName: String!

    override func setUp() {
        super.setUp()
        testSuiteName = "FitbitHealthSyncTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)
        testDefaults.removePersistentDomain(forName: testSuiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: testSuiteName)
        testDefaults = nil
        testSuiteName = nil
        super.tearDown()
    }

    func testSyncIntervalTitles() {
        XCTAssertEqual(SyncIntervalHours.every2.title, "Every 2 hours")
        XCTAssertEqual(SyncIntervalHours.every12.title, "Every 12 hours")
    }

    func testAppSettingsStoreDefaults() {
        let store = AppSettingsStore(defaults: testDefaults)

        XCTAssertEqual(store.fitbitClientID, "239Z9K")
        XCTAssertEqual(store.syncInterval, .every4)
        XCTAssertEqual(
            store.enabledMetrics,
            [.bodyWeight, .bodyFat, .steps, .sleep, .restingHeartRate, .activeEnergy]
        )
    }

    func testAppSettingsStorePersistsIntervalAndEnabledMetrics() {
        let store = AppSettingsStore(defaults: testDefaults)
        store.syncInterval = .every8
        store.enabledMetrics = [.bodyWeight, .sleep]

        let reloaded = AppSettingsStore(defaults: testDefaults)
        XCTAssertEqual(reloaded.syncInterval, .every8)
        XCTAssertEqual(reloaded.enabledMetrics, [.bodyWeight, .sleep])
    }

    func testSyncStateStoreLastSyncDateRoundTripsByMetric() {
        let store = SyncStateStore(defaults: testDefaults)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        store.setLastSyncDate(date, for: .bodyWeight)

        XCTAssertEqual(store.lastSyncDate(for: .bodyWeight), date)
        XCTAssertNil(store.lastSyncDate(for: .sleep))
    }

    func testSyncStateStoreSeenIdentifiersAreMetricScoped() {
        let store = SyncStateStore(defaults: testDefaults)
        let identifier = "fitbit-weight-123"

        XCTAssertFalse(store.hasSeen(identifier: identifier, metric: .bodyWeight))
        store.markSeen(identifier: identifier, metric: .bodyWeight)
        XCTAssertTrue(store.hasSeen(identifier: identifier, metric: .bodyWeight))
        XCTAssertFalse(store.hasSeen(identifier: identifier, metric: .bodyFat))
    }

    func testSleepDateParsing() {
        // Standard ISO 8601 with timezone (UTC)
        let date1 = SyncEngine.parseSleepDate("2020-05-16T03:01:00Z")
        XCTAssertNotNil(date1)
        
        // Standard ISO 8601 with timezone offset
        let date2 = SyncEngine.parseSleepDate("2020-05-16T03:01:00-04:00")
        XCTAssertNotNil(date2)

        // Fitbit style: ISO 8601 with fractional seconds (milliseconds) and no timezone offset
        let date3 = SyncEngine.parseSleepDate("2020-05-16T03:01:00.000")
        XCTAssertNotNil(date3)
        
        // Fitbit style: ISO 8601 without fractional seconds and no timezone offset
        let date4 = SyncEngine.parseSleepDate("2020-05-16T03:01:00")
        XCTAssertNotNil(date4)

        // Invalid format
        let dateInvalid = SyncEngine.parseSleepDate("invalid-date-format")
        XCTAssertNil(dateInvalid)
    }

    func testGoogleReversedClientID() {
        XCTAssertEqual(
            GoogleHealthConfig.reversedClientID(from: "123-abc.apps.googleusercontent.com"),
            "com.googleusercontent.apps.123-abc"
        )
        XCTAssertTrue(GoogleHealthConfig.isConfigured)
        XCTAssertEqual(
            GoogleHealthConfig.reversedClientID,
            "com.googleusercontent.apps.547556030049-csoh2cpvu82k3ub8b0gie0gk2k7mhhgc"
        )
    }

    func testDateFormattersRoundTrip() {
        let parsed = DateFormatters.parseDay("2026-08-13")
        XCTAssertEqual(DateFormatters.dayString(parsed), "2026-08-13")
    }

    func testGoogleHealthDailyFilterUsesExclusiveEndNotLessOrEqual() {
        let start = DateFormatters.parseDay("2026-08-06")
        let end = DateFormatters.parseDay("2026-08-13")
        let filter = GoogleHealthFilters.dailyDate(dataType: "daily_resting_heart_rate", start: start, end: end)
        XCTAssertFalse(filter.contains(" <= "))
        XCTAssertTrue(filter.contains(" >= \"2026-08-06\""))
        XCTAssertTrue(filter.contains(" < \"2026-08-14\""))
    }

    func testGoogleHealthSleepFilterUsesEndTime() {
        let start = Date(timeIntervalSince1970: 1_786_608_000)
        let end = Date(timeIntervalSince1970: 1_786_694_400)
        let filter = GoogleHealthFilters.sleepEndTime(start: start, end: end)
        XCTAssertTrue(filter.contains("sleep.interval.end_time"))
        XCTAssertFalse(filter.contains("start_time"))
        XCTAssertFalse(filter.contains(" <= "))
    }
}
