import XCTest

final class DocsTerminologyTests: XCTestCase {
    func testReadmesUseCurrentInformationArchitectureTerms() throws {
        let english = try repositoryText("README.md")
        let chinese = try repositoryText("README_ZH.md")
        let combined = english + "\n" + chinese

        XCTAssertFalse(combined.contains("Preview / Switching"))
        XCTAssertFalse(combined.contains("Preview and switching"))
        XCTAssertFalse(combined.contains("preview/switching"))
        XCTAssertFalse(combined.contains("预览 / 切换"))
        XCTAssertFalse(combined.contains("预览和切换"))
        XCTAssertFalse(combined.contains("左侧底部"))
        XCTAssertFalse(combined.contains("投射：关/开"))
        XCTAssertFalse(combined.contains("绿色按钮"))
        XCTAssertFalse(combined.contains("绿灯"))
        XCTAssertTrue(combined.contains("Run Desk"))
        XCTAssertTrue(combined.contains("Live Ops"))
        XCTAssertTrue(combined.contains("BGM Library"))
        XCTAssertTrue(combined.contains("Overlay Composer"))
        XCTAssertTrue(combined.contains("导播台"))
    }

    func testDocsTrackCurrentMainScreenshotTerminology() throws {
        let currentMain = try repositoryText("docs/qa/ui-current-main.md")

        XCTAssertTrue(currentMain.contains("Run Desk"))
        XCTAssertTrue(currentMain.contains("Live Ops"))
        XCTAssertTrue(currentMain.contains("Audio / BGM Library"))
        XCTAssertTrue(currentMain.contains("Overlays / Overlay Composer"))
        XCTAssertTrue(currentMain.contains("screenshots"))
        XCTAssertTrue(currentMain.contains("live-console-v0.6.0.png"))
        XCTAssertTrue(currentMain.contains("demo-only data"))
        XCTAssertFalse(currentMain.contains("预览 / 切换"))
        XCTAssertFalse(currentMain.contains("绿色按钮"))
    }

    private func repositoryText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryURL(relativePath), encoding: .utf8)
    }

    private func repositoryURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate repository file \(relativePath).")
    }
}
