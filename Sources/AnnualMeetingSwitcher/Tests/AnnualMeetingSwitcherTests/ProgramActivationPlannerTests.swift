import XCTest
@testable import LiveSwitcher

final class ProgramActivationPlannerTests: XCTestCase {
    func testMediaItemBuildsRuntimeSelectionAndNoSideEffect() throws {
        let item = mediaItem()

        let plan = try XCTUnwrap(plan(for: item, queuedItems: [item]))

        XCTAssertEqual(plan.runtimeSelection, .queued(item.id))
        XCTAssertFalse(plan.shouldStopCurrentDeckPresentation)
        XCTAssertTrue(plan.shouldClearHTML)
        XCTAssertEqual(plan.sideEffect, .none)
    }

    func testKeynoteItemBuildsPresentKeynoteSideEffectWhenValid() throws {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let item = ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item, isValidDeckDocument: { _, _ in true }))

        XCTAssertEqual(plan.sideEffect, .presentKeynote(url))
        XCTAssertTrue(plan.shouldClearHTML)
    }

    func testKeynoteInvalidDeckBuildsInvalidDeckSideEffect() throws {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let item = ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item, isValidDeckDocument: { _, _ in false }))

        XCTAssertEqual(plan.sideEffect, .invalidDeck(url))
    }

    func testPPTXItemBuildsOpenPPTXSideEffectWhenValid() throws {
        let url = URL(fileURLWithPath: "/tmp/deck.pptx")
        let item = ProgramItem(title: "Deck", subtitle: "PPTX", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item, isValidDeckDocument: { _, _ in true }))

        XCTAssertEqual(plan.sideEffect, .openPPTX(url))
        XCTAssertTrue(plan.shouldClearHTML)
    }

    func testPPTXInvalidDeckBuildsInvalidDeckSideEffect() throws {
        let url = URL(fileURLWithPath: "/tmp/deck.pptx")
        let item = ProgramItem(title: "Deck", subtitle: "PPTX", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item, isValidDeckDocument: { _, _ in false }))

        XCTAssertEqual(plan.sideEffect, .invalidDeck(url))
    }

    func testHTMLItemBuildsOpenHTMLSideEffect() throws {
        let url = URL(fileURLWithPath: "/tmp/page.html")
        let item = ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item))

        XCTAssertEqual(plan.sideEffect, .openHTML(url))
        XCTAssertFalse(plan.shouldClearHTML)
    }

    func testActiveDeckBuildsPresentActiveDeckSideEffect() throws {
        let item = ProgramItem(title: "Active", subtitle: "KEY")

        let plan = try XCTUnwrap(plan(for: item))

        XCTAssertEqual(plan.sideEffect, .presentActiveDeck)
        XCTAssertTrue(plan.shouldClearHTML)
    }

    func testAgendaMarkerBuildsNoPlan() {
        XCTAssertNil(plan(for: .agendaMarker(title: "Break")))
    }

    func testUnsupportedItemBuildsNoPlan() {
        XCTAssertNil(plan(for: ProgramItem(title: "Unsupported", subtitle: "TXT")))
    }

    func testQueuedItemUsesQueuedRuntimeSelection() throws {
        let item = mediaItem()

        let plan = try XCTUnwrap(plan(for: item, queuedItems: [item]))

        XCTAssertEqual(plan.runtimeSelection, .queued(item.id))
    }

    func testDetachedItemUsesDetachedRuntimeSelection() throws {
        let item = mediaItem()

        let plan = try XCTUnwrap(plan(for: item, queuedItems: []))

        XCTAssertEqual(plan.runtimeSelection, .detached(item))
    }

    func testStopsCurrentDeckOnlyWhenCurrentSupportsPresentationControlAndDiffers() throws {
        let current = ProgramItem(title: "Current", subtitle: "KEY")
        let next = mediaItem()

        let plan = try XCTUnwrap(plan(for: next, currentItem: current))

        XCTAssertTrue(plan.shouldStopCurrentDeckPresentation)
    }

    func testDoesNotStopCurrentDeckWhenSameItem() throws {
        let current = ProgramItem(title: "Current", subtitle: "KEY")

        let plan = try XCTUnwrap(plan(for: current, currentItem: current))

        XCTAssertFalse(plan.shouldStopCurrentDeckPresentation)
    }

    func testPlannerDoesNotReferenceSwitcherViewModel() throws {
        XCTAssertFalse(try plannerSource().contains("SwitcherViewModel"))
    }

    func testPlannerDoesNotReferenceLiveRuntimeStore() throws {
        XCTAssertFalse(try plannerSource().contains("LiveRuntimeStore"))
    }

    func testPlannerDoesNotImportAppKit() throws {
        XCTAssertFalse(try plannerSource().contains("import AppKit"))
    }

    func testPlannerDoesNotPerformViewModelOrFileSideEffects() throws {
        let source = try plannerSource()

        for forbidden in [
            "NSAlert",
            "FileManager.default",
            "recordSupportEvent",
            "dispatchRuntimeFacadeAction"
        ] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    private func plan(
        for item: ProgramItem,
        currentItem: ProgramItem? = nil,
        queuedItems: [ProgramItem] = [],
        isValidDeckDocument: (URL, ProgramSourceKind) -> Bool = { _, _ in true }
    ) -> ProgramActivationPlan? {
        ProgramActivationPlanner.plan(
            item: item,
            currentItem: currentItem,
            queuedItems: queuedItems,
            isValidDeckDocument: isValidDeckDocument
        )
    }

    private func plannerSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramActivationPlanner.swift")
    }

    private func mediaItem() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
    }
}
