import XCTest
@testable import FitbitHealthSync

final class FitbitHealthSyncTests: XCTestCase {
    func testSyncIntervalTitles() {
        XCTAssertEqual(SyncIntervalHours.every2.title, "Every 2 hours")
        XCTAssertEqual(SyncIntervalHours.every12.title, "Every 12 hours")
    }
}
