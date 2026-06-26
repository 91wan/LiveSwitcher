import XCTest
@testable import LiveSwitcher

final class ProgramQueueNumberBadgeTests: XCTestCase {
    func testBadgeMetricsProtectReadableSetupQueueNumbers() {
        let metrics = ProgramQueueNumberBadgeMetrics.metrics(for: "99", kind: .setup)

        XCTAssertGreaterThanOrEqual(metrics.height, 32)
        XCTAssertGreaterThanOrEqual(metrics.minWidth, 34)
        XCTAssertGreaterThanOrEqual(metrics.horizontalPadding, 8)
    }

    func testLiveAndMarkerBadgesUseIndependentThirtyPointScale() {
        for kind in [ProgramQueueNumberBadgeKind.live, .marker] {
            let metrics = ProgramQueueNumberBadgeMetrics.metrics(for: "20", kind: kind)

            XCTAssertGreaterThanOrEqual(metrics.height, 30)
            XCTAssertLessThanOrEqual(metrics.height, 34)
            XCTAssertGreaterThanOrEqual(metrics.minWidth, 30)
        }
    }

    func testBadgeMetricsExpandForLongStatusTextWithoutClipping() {
        let numeric = ProgramQueueNumberBadgeMetrics.metrics(for: "99", kind: .setup)
        let next = ProgramQueueNumberBadgeMetrics.metrics(for: "下一项", kind: .setup)

        XCTAssertGreaterThan(next.minWidth, numeric.minWidth)
    }

    func testDisplayTextUsesPlainArabicNumbersForLargeQueues() {
        for position in [1, 9, 10, 20, 99] {
            XCTAssertEqual(ProgramQueueNumberBadgeMetrics.displayText(for: position), "\(position)")
        }
    }

    func testQueueAndLiveSourceRowsUseSharedProgramQueueNumberBadge() throws {
        let runQueueSource = try sourceText("Views/RunQueueView.swift")
        let liveSource = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(runQueueSource.contains("ProgramQueueNumberBadge("))
        XCTAssertGreaterThanOrEqual(liveSource.components(separatedBy: "ProgramQueueNumberBadge(").count - 1, 2)
        XCTAssertTrue(liveSource.contains("PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))"))
        XCTAssertTrue(liveSource.contains("Text(item.title)"))
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
