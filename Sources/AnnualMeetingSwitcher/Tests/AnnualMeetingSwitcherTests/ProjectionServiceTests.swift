import AppKit
import XCTest
@testable import LiveSwitcher

final class ProjectionServiceTests: XCTestCase {
    func testNoExternalDisplayIsNotReady() {
        let service = ProjectionService(externalScreenProvider: { nil })

        XCTAssertFalse(service.hasExternalDisplay)
        XCTAssertNil(service.targetScreen())
    }

    func testExternalDisplayProviderPassesThroughTargetScreen() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }

        let service = ProjectionService(externalScreenProvider: { screen })

        XCTAssertTrue(service.hasExternalDisplay)
        XCTAssertTrue(service.targetScreen() === screen)
    }
}
