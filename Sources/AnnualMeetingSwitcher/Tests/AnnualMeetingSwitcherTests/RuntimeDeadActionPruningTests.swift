import XCTest

final class RuntimeDeadActionPruningTests: XCTestCase {
    func testPanicFadeCompletedActionIsRemoved() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains("panicFadeCompleted"))
    }

    func testBGMPreparedActionIsRemoved() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains("bgmPrepared"))
    }

    func testLiveRuntimeReducerDoesNotContainPanicFadeCompletedCase() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        XCTAssertFalse(source.contains("panicFadeCompleted"))
    }

    func testLiveRuntimeReducerDoesNotContainBGMPreparedCase() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        XCTAssertFalse(source.contains("bgmPrepared"))
    }

    func testRuntimeFacadeSyncPolicyDoesNotReferencePanicFadeCompleted() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeFacadeSyncPolicy.swift")

        XCTAssertFalse(source.contains("panicFadeCompleted"))
    }

    func testRuntimeFacadeSyncPolicyDoesNotReferenceBGMPrepared() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeFacadeSyncPolicy.swift")

        XCTAssertFalse(source.contains("bgmPrepared"))
    }

    func testActionLogPolicyDoesNotReferencePanicFadeCompleted() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains("return \"panicFadeCompleted\""))
    }

    func testActionLogPolicyDoesNotReferenceBGMPrepared() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains("return \"bgmPrepared\""))
    }

    func testRuntimeTimelineTestsDoNotReferencePanicFadeCompleted() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/RuntimeTimelineTests.swift")

        XCTAssertFalse(source.contains("panicFadeCompleted"))
    }

    func testRuntimeTimelineTestsDoNotReferenceBGMPrepared() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/RuntimeTimelineTests.swift")

        XCTAssertFalse(source.contains("bgmPrepared"))
    }

    func testLiveRuntimeActionDoesNotExposeDeadNoopActions() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains("case bgmPrepared"))
        XCTAssertFalse(source.contains("case panicFadeCompleted"))
    }

    func testRuntimeActionRedactedNameDoesNotExposeDeadNoopActions() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains(".bgmPrepared: return"))
        XCTAssertFalse(source.contains(".panicFadeCompleted: return"))
    }

    func testNoDeadNoopActionsRemainInProductionSources() throws {
        let sourceRoot = repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        let source = try allSwiftSource(under: sourceRoot)

        XCTAssertFalse(source.contains("bgmPrepared"))
        XCTAssertFalse(source.contains("panicFadeCompleted"))
    }

    func testNoBGMPreparedReplacementActionAdded() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.localizedStandardContains("bgmPreparedReplacement"))
    }

    func testNoPanicFadeCompletedReplacementActionAdded() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.localizedStandardContains("panicFadeCompletedReplacement"))
    }

    func testViewModelPrepareRuntimeBGMDoesNotDispatchBGMPrepared() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMRuntimePlayback.swift")
        let body = try XCTUnwrap(functionBody(named: "prepareRuntimeBGM", in: source))

        XCTAssertFalse(body.contains("dispatch"))
        XCTAssertFalse(body.contains("bgmPrepared"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func allSwiftSource(under root: URL) throws -> String {
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var combined = ""
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            combined += try String(contentsOf: file, encoding: .utf8)
            combined += "\n"
        }
        return combined
    }

    private func functionBody(named functionName: String, in source: String) -> String? {
        guard let range = source.range(of: "func \(functionName)") else { return nil }
        guard let openingBrace = source[range.lowerBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = openingBrace
        while index < source.endIndex {
            if source[index] == "{" {
                depth += 1
            } else if source[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[openingBrace...index])
                }
            }
            index = source.index(after: index)
        }
        return nil
    }
}
