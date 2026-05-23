import XCTest
@testable import LiveSwitcher

final class TabRetentionModelTests: XCTestCase {
    func testSelectedTabIsVisibleAndInteractive() {
        let model = TabRetentionModel(tab: .overlays, selectedTab: .overlays)

        XCTAssertTrue(model.isVisible)
        XCTAssertTrue(model.allowsHitTesting)
        XCTAssertFalse(model.accessibilityHidden)
    }

    func testInactiveTabStaysMountedButNonInteractiveAndAccessibilityHidden() {
        let model = TabRetentionModel(tab: .overlays, selectedTab: .audioMixer)

        XCTAssertFalse(model.isVisible)
        XCTAssertFalse(model.allowsHitTesting)
        XCTAssertTrue(model.accessibilityHidden)
    }
}
