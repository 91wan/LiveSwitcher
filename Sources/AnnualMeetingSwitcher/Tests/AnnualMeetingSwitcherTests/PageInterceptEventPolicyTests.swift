import CoreGraphics
import XCTest
@testable import LiveSwitcher

final class PageInterceptEventPolicyTests: XCTestCase {
    func testDisabledEventTypesRequestTapReenable() {
        XCTAssertEqual(
            PageInterceptEventPolicy.action(for: .tapDisabledByTimeout),
            .reenableTap(reason: .timeout)
        )
        XCTAssertEqual(
            PageInterceptEventPolicy.action(for: .tapDisabledByUserInput),
            .reenableTap(reason: .userInput)
        )
    }

    func testKeyDownIsHandledAndOtherEventsPassThrough() {
        XCTAssertEqual(PageInterceptEventPolicy.action(for: .keyDown), .handleKeyDown)
        XCTAssertEqual(PageInterceptEventPolicy.action(for: .keyUp), .passThrough)
        XCTAssertEqual(PageInterceptEventPolicy.action(for: .leftMouseDown), .passThrough)
    }
}
