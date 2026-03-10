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
}
