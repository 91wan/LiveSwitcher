import XCTest
@testable import LiveSwitcher

final class BGMRuntimeReducerHardeningTests: XCTestCase {
    func testBGMRuntimeReducerMayCallRuntimeAudioHelpers() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/BGMRuntimeReducer.swift")

        XCTAssertTrue(source.contains("AudioRuntimeReducer.syncRoutingContextFromMirrorState"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.recalculateAudio"))
    }

    func testViewModelFilesDoNotCallLiveRuntimeReducerRecalculateAudio() throws {
        for path in try viewModelSourcePaths() {
            let source = try repositorySource(path)

            XCTAssertFalse(source.contains("LiveRuntimeReducer.recalculateAudio"), path)
        }
    }

    func testViewModelFilesDoNotCallLiveRuntimeReducerSyncAudioRoutingContext() throws {
        for path in try viewModelSourcePaths() {
            let source = try repositorySource(path)

            XCTAssertFalse(source.contains("LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState"), path)
        }
    }

    func testAudioReducerExtractionIsDocumentedAsComplete() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(docs.localizedStandardContains("AudioRuntimeReducer"))
        XCTAssertFalse(docs.contains("AudioRuntimeReducer extraction remains future work"))
    }

    private func viewModelSourcePaths() throws -> [String] {
        let root = try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        let files = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )
        return files
            .filter { $0.lastPathComponent.hasPrefix("ViewModel") && $0.pathExtension == "swift" }
            .map { "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/\($0.lastPathComponent)" }
    }
}
