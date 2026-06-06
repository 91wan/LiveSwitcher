import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueRuntimeActionLogTests: XCTestCase {
    func testFacadeLoadedProgramQueueIsNotLogged() {
        let store = makeStore()

        store.dispatch(.facadeLoadedProgramQueue([programItem("Loaded")]))

        XCTAssertFalse(store.actionLog.contains { $0.actionName == "facadeLoadedProgramQueue" })
    }

    func testOperatorAddedProgramItemsIsLoggedByRedactedName() {
        let store = makeStore()

        store.dispatch(.operatorAddedProgramItems([programItem("Added")]))

        XCTAssertTrue(store.actionLog.contains { $0.actionName == "operatorAddedProgramItems" })
    }

    func testOperatorRemovedProgramItemIsLoggedByRedactedName() {
        let item = programItem("Removed")
        let store = makeStore(initialItems: [item])

        store.dispatch(.operatorRemovedProgramItem(item.id))

        XCTAssertTrue(store.actionLog.contains { $0.actionName == "operatorRemovedProgramItem" })
    }

    func testProgramQueueActionLogSummaryIncludesQueueCount() {
        let store = makeStore()

        store.dispatch(.operatorAddedProgramItems([programItem("Added")]))

        XCTAssertTrue(store.actionLog.last?.newStateSummary.contains("queueCount=1") == true)
    }

    func testProgramQueueActionLogSummaryDoesNotContainProgramTitles() {
        let title = "Private Title"
        let store = makeStore()

        store.dispatch(.operatorAddedProgramItems([programItem(title)]))

        XCTAssertFalse(store.actionLog.last?.newStateSummary.contains(title) == true)
    }

    func testProgramQueueActionLogSummaryDoesNotContainFilePaths() {
        let store = makeStore()

        store.dispatch(.operatorAddedProgramItems([programItem("Path")]))

        XCTAssertFalse(store.actionLog.last?.newStateSummary.contains("/tmp/Path.mp4") == true)
    }

    private func makeStore(initialItems: [ProgramItem] = []) -> LiveRuntimeStore {
        var state = LiveRuntimeState()
        state.program.items = initialItems
        return LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramQueueOwning()
        )
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
