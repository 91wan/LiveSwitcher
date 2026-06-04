import XCTest
@testable import LiveSwitcher

final class SupportRuntimeCoalescingTests: XCTestCase {
    func testRepeatedAutomationFailureCoalescesInRuntimeState() throws {
        var state = SupportRuntimeState()
        state.record(kind: .appleScriptFailed, detail: "action=keynote.open,error=failed", at: Date(timeIntervalSince1970: 100))
        let accepted = state.record(kind: .appleScriptFailed, detail: "action=keynote.open,error=failed", at: Date(timeIntervalSince1970: 101))

        let event = try XCTUnwrap(state.events.first)
        XCTAssertEqual(state.events.count, 1)
        XCTAssertTrue(event.detail.contains("count=2"))
        XCTAssertEqual(accepted, event)
    }

    func testChangingAutomationFailureDetailsStaySeparate() {
        var state = SupportRuntimeState()
        state.record(kind: .appleScriptFailed, detail: "action=keynote.open,error=failed-one", at: Date(timeIntervalSince1970: 100))
        state.record(kind: .appleScriptFailed, detail: "action=keynote.open,error=failed-two", at: Date(timeIntervalSince1970: 101))

        XCTAssertEqual(state.events.count, 2)
    }

    func testCoalescingKeepsRedactedBaseDetail() throws {
        var state = SupportRuntimeState()
        state.record(kind: .appleScriptFailed, detail: "action=keynote.open,error=/Users/operator/private.key", at: Date(timeIntervalSince1970: 100))
        state.record(kind: .appleScriptFailed, detail: "action=keynote.open,error=/Users/operator/private.key", at: Date(timeIntervalSince1970: 101))

        let event = try XCTUnwrap(state.events.first)
        XCTAssertFalse(event.detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(event.detail.localizedStandardContains("private.key"))
        XCTAssertTrue(event.detail.contains("count=2"))
    }

    func testCoalescingIsNotImplementedInViewModelRecordSupportEvent() throws {
        let body = try String(contentsOf: try viewModelSourceURL())

        XCTAssertFalse(body.contains("private func supportEventCoalescedCount"))
        XCTAssertFalse(body.contains("private func shouldCoalesce"))
    }

    private func viewModelSourceURL() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate ViewModel.swift from test source path.")
    }
}
