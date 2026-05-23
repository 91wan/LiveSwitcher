import XCTest
@testable import LiveSwitcher

final class OverlaySpeedSelectionTests: XCTestCase {
    func testKnownTickerSpeedsMapToMatchingIndexes() {
        XCTAssertEqual(OverlaySpeedSelection.nearestIndex(for: 55), 0)
        XCTAssertEqual(OverlaySpeedSelection.nearestIndex(for: 85), 1)
        XCTAssertEqual(OverlaySpeedSelection.nearestIndex(for: 130), 2)
    }

    func testUnknownTickerSpeedMapsToNearestIndex() {
        XCTAssertEqual(OverlaySpeedSelection.nearestIndex(for: 100), 1)
    }

    func testSpeedLookupClampsOutOfRangeIndex() {
        XCTAssertEqual(OverlaySpeedSelection.speed(at: -1), 55)
        XCTAssertEqual(OverlaySpeedSelection.speed(at: 99), 130)
    }
}
