import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class OutputWindowPresentationTests: XCTestCase {
    func testOutputWindowCannotBecomeKeyOrMain() {
        let window = NonActivatingOutputWindow(
            contentRect: NSRect(x: 0, y: 0, width: 128, height: 72),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        XCTAssertFalse(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
    }

    func testOutputWindowPresentationConfigurationIgnoresMouseEvents() {
        let window = NonActivatingOutputWindow(
            contentRect: NSRect(x: 0, y: 0, width: 128, height: 72),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        OutputWindowPresentationPolicy.configure(window)

        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertFalse(window.canBecomeKey)
    }
}
