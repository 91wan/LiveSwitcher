import XCTest
@testable import LiveSwitcher

final class ProgramQueueRuntimeStateTests: XCTestCase {
    func testAddedProgramItemsAppendsItemsWhenOwned() {
        let first = programItem("First")
        let second = programItem("Second")

        let mutation = reduce(.operatorAddedProgramItems([first, second]), bridgeMode: .programQueueOwned)

        XCTAssertEqual(mutation.state.program.items, [first, second])
        XCTAssertEqual(mutation.effects, [])
    }

    func testAddedProgramItemsNoopsBeforeOwnership() {
        let item = programItem("First")

        let mutation = reduce(.operatorAddedProgramItems([item]), bridgeMode: .presentationQueryOwned)

        XCTAssertTrue(mutation.state.program.items.isEmpty)
    }

    func testRemovedProgramItemRemovesMatchingItemWhenOwned() {
        let first = programItem("First")
        let second = programItem("Second")
        var state = LiveRuntimeState()
        state.program.items = [first, second]

        let mutation = reduce(state, .operatorRemovedProgramItem(first.id), bridgeMode: .programQueueOwned)

        XCTAssertEqual(mutation.state.program.items, [second])
    }

    func testRemovedCurrentProgramClearsRuntimeCurrentIDOnly() {
        let item = programItem("Current")
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = true

        let mutation = reduce(state, .operatorRemovedProgramItem(item.id), bridgeMode: .programQueueOwned)

        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertEqual(mutation.state.media.loadedURL, item.sourceURL)
        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertEqual(mutation.effects, [])
    }

    func testMovedProgramItemsPreservesIdentityAndOrder() {
        let first = programItem("First")
        let second = programItem("Second")
        let third = programItem("Third")
        var state = LiveRuntimeState()
        state.program.items = [first, second, third]

        let mutation = reduce(state, .operatorMovedProgramItems(fromOffsets: [0], toOffset: 3), bridgeMode: .programQueueOwned)

        XCTAssertEqual(mutation.state.program.items.map(\.id), [second.id, third.id, first.id])
    }

    func testMovedProgramItemsIgnoresInvalidIndices() {
        let first = programItem("First")
        var state = LiveRuntimeState()
        state.program.items = [first]

        let mutation = reduce(state, .operatorMovedProgramItems(fromOffsets: [5], toOffset: 1), bridgeMode: .programQueueOwned)

        XCTAssertEqual(mutation.state.program.items, [first])
    }

    func testUpdatedProgramItemScheduleUpdatesExistingItem() {
        let item = programItem("Scheduled")
        let start = Date(timeIntervalSince1970: 100)
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = reduce(
            state,
            .operatorUpdatedProgramItemSchedule(id: item.id, scheduledStartAt: start, scheduledDuration: 45),
            bridgeMode: .programQueueOwned
        )

        XCTAssertEqual(mutation.state.program.items[0].scheduledStartAt, start)
        XCTAssertEqual(mutation.state.program.items[0].scheduledDuration, 45)
    }

    func testUpdatedProgramItemScheduleNoopsForMissingItem() {
        let item = programItem("Scheduled")
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = reduce(
            state,
            .operatorUpdatedProgramItemSchedule(id: UUID(), scheduledStartAt: Date(), scheduledDuration: 45),
            bridgeMode: .programQueueOwned
        )

        XCTAssertEqual(mutation.state.program.items, [item])
    }

    func testAddedAgendaMarkerUsesLastScheduledEnd() {
        let start = Date(timeIntervalSince1970: 100)
        var item = programItem("Video")
        item.scheduledStartAt = start
        item.scheduledDuration = 60
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = reduce(state, .operatorAddedAgendaMarker(title: "Break"), bridgeMode: .programQueueOwned)

        XCTAssertEqual(mutation.state.program.items.last?.title, "Break")
        XCTAssertEqual(mutation.state.program.items.last?.scheduledStartAt, start.addingTimeInterval(60))
    }

    func testFacadeLoadedProgramQueueReplacesRuntimeItems() {
        let first = programItem("First")
        let second = programItem("Second")
        var state = LiveRuntimeState()
        state.program.items = [first]

        let mutation = reduce(state, .facadeLoadedProgramQueue([second]), bridgeMode: .programQueueOwned)

        XCTAssertEqual(mutation.state.program.items, [second])
    }

    func testFacadeLoadedProgramQueueDoesNotEmitPersistenceEffect() {
        let mutation = reduce(.facadeLoadedProgramQueue([programItem("Loaded")]), bridgeMode: .programQueueOwned)

        XCTAssertFalse(mutation.effects.contains { effect in
            if case .savePersistentState = effect { return true }
            return false
        })
    }

    func testProgramQueueReducerDoesNotWriteSupport() {
        let mutation = reduce(.operatorAddedProgramItems([programItem("First")]), bridgeMode: .programQueueOwned)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testProgramQueueReducerDoesNotEmitMediaProjectionOrAutomationEffects() {
        let mutation = reduce(.operatorAddedProgramItems([programItem("First")]), bridgeMode: .programQueueOwned)

        XCTAssertFalse(mutation.effects.contains { effect in
            switch effect {
            case .loadMedia, .playMedia, .stopMedia, .startProjection, .stopProjection, .runAppleScript, .scanPresentationQuery:
                return true
            default:
                return false
            }
        })
    }

    private func reduce(_ action: LiveRuntimeAction, bridgeMode: LiveRuntimeBridgeMode) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, bridgeMode: bridgeMode)
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction, bridgeMode: LiveRuntimeBridgeMode) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
