import XCTest
@testable import LiveSwitcher

final class RunQueueLayoutMetricsTests: XCTestCase {
    func testRunQueueRowControlsUseOperatorSafeHitTarget() {
        XCTAssertGreaterThanOrEqual(RunQueueLayoutMetrics.rowControlButtonSize, 34)
    }

    func testRunQueueRowControlsUseSharedMetricInsteadOfHardcodedThirtyPointFrame() throws {
        let source = try sourceText("Views/RunQueueView.swift")

        XCTAssertTrue(source.contains("RunQueueLayoutMetrics.rowControlButtonSize"))
        XCTAssertFalse(source.contains(".frame(width: 30, height: 30)"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
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
