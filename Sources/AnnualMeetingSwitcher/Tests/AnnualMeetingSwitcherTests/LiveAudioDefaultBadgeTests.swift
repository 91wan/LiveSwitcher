import XCTest

final class LiveAudioDefaultBadgeTests: XCTestCase {
    func testLiveAudioStripUsesStatusByExceptionPolicyForRoutingBadge() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertFalse(source.contains("StatusBadge(viewModel.audioStrategy.displayTitle, kind: audioStatusKind)"))
        XCTAssertTrue(
            source.contains("StatusBadgeVisibilityPolicy.shouldShow(text: audioStatusText, kind: audioStatusKind)"),
            "Live Audio Strip should hide normal routing badges and show only status exceptions."
        )
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
