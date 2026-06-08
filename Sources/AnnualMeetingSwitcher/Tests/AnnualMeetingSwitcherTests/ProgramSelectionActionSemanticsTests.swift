import XCTest
@testable import LiveSwitcher

final class ProgramSelectionActionSemanticsTests: XCTestCase {
    func testOperatorSelectedProgramRedactedName() {
        XCTAssertEqual(
            LiveRuntimeAction.operatorSelectedProgram(UUID()).redactedName,
            "operatorSelectedProgram"
        )
    }

    func testOperatorSelectedDetachedProgramRedactedName() {
        XCTAssertEqual(
            LiveRuntimeAction.operatorSelectedDetachedProgram(programItem("Detached")).redactedName,
            "operatorSelectedDetachedProgram"
        )
    }

    func testOperatorSelectedDetachedProgramRedactedNameDiffersFromQueuedSelection() {
        let item = programItem("Detached")

        XCTAssertNotEqual(
            LiveRuntimeAction.operatorSelectedProgram(item.id).redactedName,
            LiveRuntimeAction.operatorSelectedDetachedProgram(item).redactedName
        )
    }

    func testOperatorSelectedDetachedProgramRedactedNameDoesNotContainTitle() {
        let item = programItem("Private Title")

        XCTAssertFalse(LiveRuntimeAction.operatorSelectedDetachedProgram(item).redactedName.contains("Private Title"))
    }

    func testOperatorSelectedDetachedProgramRedactedNameDoesNotContainFilePath() {
        let item = programItem("Private Title")

        XCTAssertFalse(LiveRuntimeAction.operatorSelectedDetachedProgram(item).redactedName.contains("/tmp/Private Title.mp4"))
    }

    func testOperatorClearedCurrentProgramRedactedName() {
        XCTAssertEqual(
            LiveRuntimeAction.operatorClearedCurrentProgram(reason: .operatorCleared).redactedName,
            "operatorClearedCurrentProgram"
        )
    }

    func testFacadeCurrentProgramChangedRedactedNameRemainsCompatibilityName() {
        XCTAssertEqual(
            LiveRuntimeAction.facadeCurrentProgramChanged(UUID()).redactedName,
            "facadeCurrentProgramChanged"
        )
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
