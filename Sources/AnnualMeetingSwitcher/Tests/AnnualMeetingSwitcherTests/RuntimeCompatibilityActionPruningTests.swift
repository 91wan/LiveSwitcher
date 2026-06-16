import XCTest

final class RuntimeCompatibilityActionPruningTests: XCTestCase {
    func testFacadeCurrentProgramChangedActionIsRemoved() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains("case facadeCurrentProgramChanged"))
    }

    func testLiveRuntimeReducerDoesNotContainFacadeCurrentProgramChangedCase() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        XCTAssertFalse(source.contains("facadeCurrentProgramChanged"))
    }

    func testRuntimeFacadeSyncPolicyDoesNotReferenceFacadeCurrentProgramChanged() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeFacadeSyncPolicy.swift")

        XCTAssertFalse(source.contains("facadeCurrentProgramChanged"))
    }

    func testActionLogPolicyDoesNotReferenceFacadeCurrentProgramChanged() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeStore.swift")

        XCTAssertFalse(source.contains("facadeCurrentProgramChanged"))
    }

    func testRuntimeActionRedactedNameDoesNotExposeFacadeCurrentProgramChanged() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains("return \"facadeCurrentProgramChanged\""))
    }

    func testProgramSelectionRuntimeReducerDoesNotContainFacadeMirrorMethod() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/ProgramSelectionRuntimeReducer.swift")

        XCTAssertFalse(source.contains("applyFacadeCurrentProgramChanged"))
    }

    func testNoFacadeCurrentProgramChangedReplacementActionAdded() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.localizedStandardContains("currentProgramMirror"))
        XCTAssertFalse(source.localizedStandardContains("facadeSelectionChanged"))
        XCTAssertFalse(source.localizedStandardContains("facadeCurrentProgramChanged2"))
    }

    func testNoCurrentProgramCompatibilityReplacementActionAdded() throws {
        let sourceRoot = repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        let source = try allSwiftSource(under: sourceRoot)

        XCTAssertFalse(source.localizedStandardContains("currentProgramMirror"))
        XCTAssertFalse(source.localizedStandardContains("facadeSelectionChanged"))
        XCTAssertFalse(source.localizedStandardContains("facadeCurrentProgramChanged2"))
    }

    func testNoDeadCompatibilityActionRemainsInProductionSources() throws {
        let sourceRoot = repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        let source = try allSwiftSource(under: sourceRoot)

        XCTAssertFalse(source.contains("facadeCurrentProgramChanged"))
    }

    func testNoTestsConstructFacadeCurrentProgramChangedAction() throws {
        let testsRoot = repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests")
        let source = try allSwiftSource(under: testsRoot, excluding: URL(fileURLWithPath: #filePath))

        XCTAssertFalse(source.contains(".facadeCurrentProgramChanged("))
        XCTAssertFalse(source.contains("LiveRuntimeAction.facadeCurrentProgramChanged("))
    }

    func testProductionSelectionPathsUseRealOperatorActions() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")

        XCTAssertTrue(source.contains(".operatorSelectedProgram("))
        XCTAssertTrue(source.contains(".operatorSelectedDetachedProgram("))
        XCTAssertFalse(source.contains("facadeCurrentProgramChanged"))
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

    private func allSwiftSource(under root: URL, excluding excludedFile: URL? = nil) throws -> String {
        let excludedPath = excludedFile?.standardizedFileURL.path
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var combined = ""
        while let file = enumerator?.nextObject() as? URL {
            guard file.pathExtension == "swift" else { continue }
            guard file.standardizedFileURL.path != excludedPath else { continue }
            combined += try String(contentsOf: file, encoding: .utf8)
            combined += "\n"
        }
        return combined
    }
}
