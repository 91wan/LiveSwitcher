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

        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 49))
    }

    @MainActor
    func testSpaceShortcutPassesThroughFocusedNativeControls() {
        let eventWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let toggle = NSSwitch(frame: NSRect(x: 0, y: 0, width: 60, height: 28))
        eventWindow.contentView = toggle
        eventWindow.makeFirstResponder(toggle)

        XCTAssertTrue(
            GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 49),
            "Space should toggle a focused native control instead of global media playback."
        )
        XCTAssertTrue(
            GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 30),
            "Non-space shortcuts should still respect native control focus."
        )
    }

    @MainActor
    func testNumberShortcutsPassThroughFocusedNativeControls() {
        let eventWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let toggle = NSSwitch(frame: NSRect(x: 0, y: 0, width: 60, height: 28))
        eventWindow.contentView = toggle
        eventWindow.makeFirstResponder(toggle)

        XCTAssertTrue(
            GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 18),
            "Number keys should stay with focused native controls."
        )
        XCTAssertTrue(
            GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 25),
            "All 1-9 program shortcuts should pass through when a native control is focused."
        )
    }

    @MainActor
    func testButtonAndSliderFocusPassThroughNonEmergencyShortcuts() {
        let eventWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 90),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        let button = NSButton(title: "Toggle", target: nil, action: nil)
        eventWindow.contentView = button
        eventWindow.makeFirstResponder(button)

        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 49))
        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 18))
        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 33))
        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 30))
        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 43))

        let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
        eventWindow.contentView = slider
        eventWindow.makeFirstResponder(slider)

        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 123))
        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 124))
        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 18))
    }

    @MainActor
    func testSpaceShortcutStillPassesThroughFocusedTextInput() {
        let eventWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        eventWindow.contentView = textView
        eventWindow.makeFirstResponder(textView)

        XCTAssertTrue(GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: eventWindow, keyCode: 49))
    }

    func testKeyMonitorUsesEventWindowForScopeAndResponderChecks() throws {
        let content = try sourceText("Views/AppShell/GlobalKeyMonitor.swift")

        XCTAssertTrue(content.contains("GlobalShortcutPolicy.shouldHandleEvent(monitorWindow: window, eventWindow: event.window)"))
        XCTAssertTrue(content.contains("GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: event.window, keyCode: event.keyCode)"))
        XCTAssertFalse(content.contains("window?.firstResponder"))
    }

    func testKeyMonitorKeepsEmergencyPanicBeforeFocusedResponderPassThrough() throws {
        let content = try sourceText("Views/AppShell/GlobalKeyMonitor.swift")
        let panicRange = try XCTUnwrap(content.range(of: "GlobalShortcutPolicy.isEmergencyPanicShortcut"))
        let passThroughRange = try XCTUnwrap(
            content.range(of: "GlobalShortcutPolicy.shouldPassThroughFocusedResponder")
        )

        XCTAssertLessThan(
            panicRange.lowerBound,
            passThroughRange.lowerBound,
            "Emergency panic must remain global even when a native control owns keyboard focus."
        )
    }

    func testProgramNumberShortcutTargetSkipsAgendaMarkersAndOutOfRangeItems() {
        let first = ProgramItem(title: "Opening", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4"))
        let marker = ProgramItem.agendaMarker(title: "茶歇")
        let second = ProgramItem(title: "Awards", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/awards.mp4"))
        let items = [first, marker, second]

        XCTAssertEqual(GlobalShortcutPolicy.programShortcutTargetIndex(for: 18, in: items), 0)
        XCTAssertNil(
            GlobalShortcutPolicy.programShortcutTargetIndex(for: 19, in: items),
            "Number shortcut targeting an agenda marker should pass the event through instead of consuming it."
        )
        XCTAssertEqual(GlobalShortcutPolicy.programShortcutTargetIndex(for: 20, in: items), 2)
        XCTAssertNil(GlobalShortcutPolicy.programShortcutTargetIndex(for: 21, in: items))
        XCTAssertNil(GlobalShortcutPolicy.programShortcutTargetIndex(for: 49, in: items))
    }

    func testKeyMonitorOnlyConsumesNumberShortcutsForPlayableTargets() throws {
        let content = try sourceText("Views/AppShell/GlobalKeyMonitor.swift")

        XCTAssertTrue(content.contains("vm.programShortcutTargetIndex(forKeyCode: event.keyCode)"))
        XCTAssertFalse(content.contains("vm.switchToProgram(at: idx - 1)"))
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
