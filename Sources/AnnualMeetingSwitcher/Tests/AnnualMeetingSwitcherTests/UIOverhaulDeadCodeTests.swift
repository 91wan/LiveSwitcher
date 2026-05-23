import XCTest

final class UIOverhaulDeadCodeTests: XCTestCase {
    func testRightPanelDeadCodeWasRemovedAfterLiveOpsReplacement() throws {
        let root = try sourceRoot()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: root.appendingPathComponent("Views/RightPanel.swift").path),
            "RightPanel.swift should not remain after LiveOpsPanel and AudioMixerView own the active paths."
        )
    }

    func testBGMPlaylistPanelIsLibraryOnly() throws {
        let content = try String(contentsOf: sourceURL("Views/BGMPlaylistPanel.swift"), encoding: .utf8)

        XCTAssertFalse(content.contains("BGMPlaylistPanelMode"))
        XCTAssertFalse(content.contains("liveDock"))
        XCTAssertFalse(content.contains("mode =="))
        XCTAssertFalse(content.contains("init(mode:"))
    }

    func testBusinessEnumsLiveInModelsNotViewFiles() throws {
        let audioStrategy = try String(contentsOf: sourceURL("Models/AudioStrategy.swift"), encoding: .utf8)
        let bgmCategory = try String(contentsOf: sourceURL("Models/BGMCategory.swift"), encoding: .utf8)

        XCTAssertTrue(audioStrategy.contains("enum AudioStrategy"))
        XCTAssertTrue(audioStrategy.contains("init?(persistedValue:"))
        XCTAssertTrue(bgmCategory.contains("enum BGMCategory"))
    }

    private func sourceRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
        }
        throw XCTSkip("Could not locate app source root from test source path.")
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        let candidate = try sourceRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw XCTSkip("Could not locate \(relativePath) from test source path.")
        }
        return candidate
    }
}
