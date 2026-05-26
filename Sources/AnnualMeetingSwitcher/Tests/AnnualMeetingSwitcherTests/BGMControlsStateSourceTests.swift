import XCTest

final class BGMControlsStateSourceTests: XCTestCase {
    func testPlayingStatusDocumentsReadyAsSafeActiveAudioNotCriticalLive() throws {
        let source = try sourceText("Models/BGMControlsState.swift")

        XCTAssertTrue(source.contains("safe active audio"))
        XCTAssertTrue(source.contains("not critical projection state"))
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
