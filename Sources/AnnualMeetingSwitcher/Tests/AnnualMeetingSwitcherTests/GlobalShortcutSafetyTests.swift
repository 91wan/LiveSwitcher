import AppKit
import XCTest
@testable import LiveSwitcher

final class GlobalShortcutSafetyTests: XCTestCase {
    func testCommandOptionBTriggersPanicShortcut() {
        XCTAssertTrue(
            GlobalShortcutPolicy.isEmergencyPanicShortcut(
                keyCode: 11,
                modifierFlags: [.command, .option]
            )
        )
    }

    func testCommandOptionShiftBDoesNotTriggerPanicShortcut() {
        XCTAssertFalse(
            GlobalShortcutPolicy.isEmergencyPanicShortcut(
                keyCode: 11,
                modifierFlags: [.command, .option, .shift]
            )
        )
    }

    func testShiftModifiedNonEmergencyKeysAreIgnored() {
        XCTAssertTrue(GlobalShortcutPolicy.hasNonEmergencyShortcutModifiers([.shift]))
        XCTAssertTrue(GlobalShortcutPolicy.hasNonEmergencyShortcutModifiers([.command]))
        XCTAssertFalse(GlobalShortcutPolicy.hasNonEmergencyShortcutModifiers([]))
    }
}
