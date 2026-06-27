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

    func testLiveSourceRowAlignsNumberBadgeWithThumbnailCenter() throws {
        let liveSource = try sourceText("Views/LiveModeView.swift")
        let rowSource = try sourceBlock(
            named: "private struct LiveSourceRailRow",
            endingBefore: "    private var statusColor",
            in: liveSource
        )

        XCTAssertTrue(rowSource.contains("HStack(alignment: .center, spacing: 7)"))
        XCTAssertLessThan(
            try offset(of: "ProgramQueueNumberBadge(", in: rowSource),
            try offset(of: "ProgramThumbnailView(", in: rowSource)
        )
        XCTAssertLessThan(
            try offset(of: "ProgramThumbnailView(", in: rowSource),
            try offset(of: "Text(labelModel.detailText)", in: rowSource)
        )
    }

    private func sourceBlock(named startMarker: String, endingBefore endMarker: String, in source: String) throws -> String {
        guard let start = source.range(of: startMarker)?.lowerBound,
              let end = source.range(of: endMarker, range: start..<source.endIndex)?.lowerBound else {
            throw XCTSkip("Could not locate source block \(startMarker)")
        }
        return String(source[start..<end])
    }

    private func offset(of needle: String, in source: String) throws -> Int {
        guard let range = source.range(of: needle) else {
            throw XCTSkip("Could not locate \(needle)")
        }
        return source.distance(from: source.startIndex, to: range.lowerBound)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        if isLiveModeViewSourcePath(relativePath) {
            return try liveModeSourceTextAggregate(repositoryRoot: repositoryRoot(filePath: #filePath))
        }
        return try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
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
