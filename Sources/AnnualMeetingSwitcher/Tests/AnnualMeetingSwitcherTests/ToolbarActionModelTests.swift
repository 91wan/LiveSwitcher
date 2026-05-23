import XCTest
@testable import LiveSwitcher

final class ToolbarActionModelTests: XCTestCase {
    func testTopToolbarOnlyContainsGlobalCriticalAndHelpActions() {
        let actions = ToolbarActionModel.topActions.map(\.id)

        XCTAssertEqual(actions, [.panic, .preflight, .help])
        XCTAssertFalse(actions.contains(.speaker))
        XCTAssertFalse(actions.contains(.ppt))
    }
}
