import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramSelectionRuntimeActionLogTests: XCTestCase {
    func testFacadeCurrentProgramChangedIsNotLogged() {
        let store = makeStore()
        let item = programItem("Current")

        store.dispatch(.facadeCurrentProgramChanged(item.id))

        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.facadeCurrentProgramChanged(item.id)))
        XCTAssertFalse(store.actionLog.contains { $0.actionName == "facadeCurrentProgramChanged" })
    }

    func testOperatorSelectedProgramIsLoggedWithRedactedName() {
        let item = programItem("Private Title")
        let store = makeStore(initialItems: [item])

        store.dispatch(.operatorSelectedProgram(item.id))

        XCTAssertTrue(store.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testSelectionActionLogDoesNotContainTitleOrPath() {
        let item = programItem("Private Title")
        let store = makeStore(initialItems: [item])

        store.dispatch(.operatorSelectedProgram(item.id))

        let log = store.actionLog.map { "\($0.oldStateSummary)|\($0.newStateSummary)" }.joined(separator: "\n")
        XCTAssertFalse(log.contains("Private Title"))
        XCTAssertFalse(log.contains("/tmp/Private Title.mp4"))
    }

    func testOperatorClearedCurrentProgramIsLoggedWithRedactedNameOnly() {
        let item = programItem("Private Title")
        let store = makeStore(initialItems: [item])
        store.dispatch(.operatorSelectedProgram(item.id))

        store.dispatch(.operatorClearedCurrentProgram(reason: .htmlPresentationEnded))

        XCTAssertTrue(store.actionLog.contains { $0.actionName == "operatorClearedCurrentProgram" })
        let log = store.actionLog.map { "\($0.actionName)|\($0.oldStateSummary)|\($0.newStateSummary)" }.joined(separator: "\n")
        XCTAssertFalse(log.contains("htmlPresentationEnded"))
        XCTAssertFalse(log.contains("Private Title"))
        XCTAssertFalse(log.contains("/tmp/Private Title.mp4"))
    }

    private func makeStore(initialItems: [ProgramItem] = []) -> LiveRuntimeStore {
        var state = LiveRuntimeState()
        state.program.items = initialItems
        return LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramSelectionOwning()
        )
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
