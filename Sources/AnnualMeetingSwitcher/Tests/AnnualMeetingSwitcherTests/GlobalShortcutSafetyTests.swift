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

    @MainActor
    func testShortcutsIgnoreEventsFromOtherWindows() {
        let monitorWindow = NSWindow(
            contentRect: .zero,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let otherWindow = NSWindow(
            contentRect: .zero,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        XCTAssertTrue(GlobalShortcutPolicy.shouldHandleEvent(monitorWindow: monitorWindow, eventWindow: monitorWindow))
        XCTAssertFalse(GlobalShortcutPolicy.shouldHandleEvent(monitorWindow: monitorWindow, eventWindow: otherWindow))
        XCTAssertFalse(GlobalShortcutPolicy.shouldHandleEvent(monitorWindow: monitorWindow, eventWindow: nil))
    }

    @MainActor
    func testFocusedResponderComesFromEventWindow() {
        let eventWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        eventWindow.contentView = textView
        eventWindow.makeFirstResponder(textView)

        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow))
    }

    func testKeyMonitorUsesEventWindowForScopeAndResponderChecks() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(content.contains("GlobalShortcutPolicy.shouldHandleEvent(monitorWindow: window, eventWindow: event.window)"))
        XCTAssertTrue(content.contains("GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: event.window)"))
        XCTAssertFalse(content.contains("window?.firstResponder"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
