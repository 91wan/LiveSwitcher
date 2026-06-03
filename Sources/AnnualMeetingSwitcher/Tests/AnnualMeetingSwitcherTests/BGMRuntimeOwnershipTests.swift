import XCTest
@testable import LiveSwitcher

final class BGMRuntimeOwnershipTests: XCTestCase {
    func testViewModelDoesNotDirectlyCreateAVAudioPlayerInToggleBGM() throws {
        let body = try toggleBGMBody()

        XCTAssertFalse(body.contains("AVAudioPlayer(contentsOf:"))
    }

    func testViewModelDoesNotDirectlyReplaceFallbackPlayerInToggleBGM() throws {
        let body = try toggleBGMBody()

        XCTAssertFalse(body.contains("bgmFallbackPlayer.replaceCurrentItem"))
    }

    func testViewModelDoesNotDirectlyStartStopBGMTimerInToggleBGM() throws {
        let body = try toggleBGMBody()

        XCTAssertFalse(body.contains("startBGMTimer()"))
        XCTAssertFalse(body.contains("stopBGMTimer()"))
    }

    private func toggleBGMBody() throws -> String {
        let source = try sourceText("ViewModel.swift")
        guard let start = source.range(of: "    func toggleBGM(_ item: BGMItem) {"),
              let end = source.range(of: "    private func cueBGMDuringPanic", range: start.upperBound..<source.endIndex)
        else {
            XCTFail("toggleBGM body not found")
            return ""
        }
        return String(source[start.upperBound..<end.lowerBound])
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent(relativePath)
        ]
        if let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return url
        }
        return candidates[0]
    }
}
