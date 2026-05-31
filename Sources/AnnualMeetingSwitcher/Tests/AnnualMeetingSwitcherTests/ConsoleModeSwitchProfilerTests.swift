import XCTest
@testable import LiveSwitcher

final class ConsoleModeSwitchProfilerTests: XCTestCase {
    func testShortSwitchDoesNotNeedSupportEvent() {
        let start = ConsoleModeSwitchProfiler.begin(targetMode: .live, now: Date(timeIntervalSince1970: 100))

        let event = ConsoleModeSwitchProfiler.end(start, now: Date(timeIntervalSince1970: 100.2))

        XCTAssertEqual(event.targetMode, .live)
        XCTAssertEqual(event.duration, 0.2, accuracy: 0.0001)
        XCTAssertFalse(event.shouldLogWarning)
        XCTAssertFalse(event.shouldRecordSupportEvent)
        XCTAssertNil(event.supportEventDetail)
    }

    func testWarningSwitchLogsWithoutSupportEvent() {
        let start = ConsoleModeSwitchProfiler.begin(targetMode: .setup, now: Date(timeIntervalSince1970: 200))

        let event = ConsoleModeSwitchProfiler.end(start, now: Date(timeIntervalSince1970: 200.7))

        XCTAssertTrue(event.shouldLogWarning)
        XCTAssertFalse(event.shouldRecordSupportEvent)
        XCTAssertNil(event.supportEventDetail)
    }

    func testSlowSwitchRecordsSanitizedSupportEventDetail() throws {
        let start = ConsoleModeSwitchProfiler.begin(targetMode: .live, now: Date(timeIntervalSince1970: 300))

        let event = ConsoleModeSwitchProfiler.end(start, now: Date(timeIntervalSince1970: 301.25))

        XCTAssertTrue(event.shouldLogWarning)
        XCTAssertTrue(event.shouldRecordSupportEvent)
        let detail = try XCTUnwrap(event.supportEventDetail)
        XCTAssertTrue(detail.contains("targetMode=live"))
        XCTAssertTrue(detail.contains("durationMs=1250"))
        XCTAssertFalse(detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(detail.localizedStandardContains("Private"))
    }

    func testContentViewConnectsProfilerToConsoleModeChanges() throws {
        let source = try sourceText("ContentView.swift")

        XCTAssertTrue(source.contains("ConsoleModeSwitchProfiler.begin"))
        XCTAssertTrue(source.contains("ConsoleModeSwitchProfiler.end"))
        XCTAssertTrue(source.contains("consoleModeSwitchSlow"))
        XCTAssertTrue(source.contains("Task { @MainActor"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
