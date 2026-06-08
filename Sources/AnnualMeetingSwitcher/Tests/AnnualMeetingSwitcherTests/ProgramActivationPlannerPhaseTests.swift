import XCTest
@testable import LiveSwitcher

final class ProgramActivationPlannerPhaseTests: XCTestCase {
    func testMediaPlannerBuildsQueuedSelection() throws {
        let item = mediaItem()

        let plan = try XCTUnwrap(plan(for: item, queuedItems: [item]))

        XCTAssertEqual(plan.runtimeSelection, .queued(item.id))
    }

    func testMediaPlannerBuildsDetachedSelection() throws {
        let item = mediaItem()

        let plan = try XCTUnwrap(plan(for: item, queuedItems: []))

        XCTAssertEqual(plan.runtimeSelection, .detached(item))
    }

    func testMediaPlannerBuildsPostSelectionClearHTMLAndResetMutedStartup() throws {
        let item = mediaItem()

        let plan = try XCTUnwrap(plan(for: item, queuedItems: [item]))

        XCTAssertEqual(plan.preSelectionEffects, [])
        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .resetMutedMediaStartupFlag])
    }

    func testKeynotePlannerBuildsPresentKeynoteAfterClearHTML() throws {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let item = ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item, isValidDeckDocument: { _, _ in true }))

        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .presentKeynote(url)])
    }

    func testKeynoteInvalidDeckBuildsPreSelectionInvalidDeckAlert() throws {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let item = ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item, isValidDeckDocument: { _, _ in false }))

        XCTAssertNil(plan.runtimeSelection)
        XCTAssertEqual(plan.preSelectionEffects, [.presentInvalidDeckAlert(url)])
        XCTAssertTrue(plan.abortsBeforeSelection)
        XCTAssertEqual(plan.postSelectionEffects, [])
    }

    func testPPTXPlannerBuildsOpenPPTXAfterClearHTML() throws {
        let url = URL(fileURLWithPath: "/tmp/deck.pptx")
        let item = ProgramItem(title: "Slides", subtitle: "PPTX", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item, isValidDeckDocument: { _, _ in true }))

        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .openPPTX(url)])
    }

    func testPPTXInvalidDeckBuildsPreSelectionInvalidDeckAlert() throws {
        let url = URL(fileURLWithPath: "/tmp/deck.pptx")
        let item = ProgramItem(title: "Slides", subtitle: "PPTX", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item, isValidDeckDocument: { _, _ in false }))

        XCTAssertNil(plan.runtimeSelection)
        XCTAssertEqual(plan.preSelectionEffects, [.presentInvalidDeckAlert(url)])
        XCTAssertTrue(plan.abortsBeforeSelection)
        XCTAssertEqual(plan.postSelectionEffects, [])
    }

    func testHTMLPlannerBuildsOpenHTMLWithoutClearHTML() throws {
        let url = URL(fileURLWithPath: "/tmp/page.html")
        let item = ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: url)

        let plan = try XCTUnwrap(plan(for: item))

        XCTAssertEqual(plan.postSelectionEffects, [.openHTML(url)])
        XCTAssertFalse(plan.postSelectionEffects.contains(.clearHTML))
    }

    func testActiveDeckPlannerBuildsPresentActiveDeckAfterClearHTML() throws {
        let item = ProgramItem(title: "Active", subtitle: "KEY")

        let plan = try XCTUnwrap(plan(for: item))

        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .presentActiveDeck])
    }

    func testStopDeckAddedOnlyWhenCurrentSupportsPresentationControlAndDiffers() throws {
        let current = ProgramItem(title: "Current", subtitle: "KEY")
        let next = mediaItem()

        let plan = try XCTUnwrap(plan(for: next, currentItem: current))

        XCTAssertEqual(plan.preSelectionEffects, [.stopDeck])
    }

    func testNoStopDeckWhenCurrentProgramIsSame() throws {
        let current = ProgramItem(title: "Current", subtitle: "KEY")

        let plan = try XCTUnwrap(plan(for: current, currentItem: current))

        XCTAssertFalse(plan.preSelectionEffects.contains(.stopDeck))
    }

    func testAgendaMarkerStillBuildsNoPlan() {
        XCTAssertNil(plan(for: .agendaMarker(title: "Break")))
    }

    func testUnsupportedStillBuildsNoPlan() {
        XCTAssertNil(plan(for: ProgramItem(title: "Unsupported", subtitle: "TXT")))
    }

    func testPlannerStillDoesNotReferenceSwitcherViewModel() throws {
        XCTAssertFalse(try plannerSource().contains("SwitcherViewModel"))
    }

    func testPlannerStillDoesNotReferenceLiveRuntimeStore() throws {
        XCTAssertFalse(try plannerSource().contains("LiveRuntimeStore"))
    }

    func testPlannerStillDoesNotImportAppKit() throws {
        XCTAssertFalse(try plannerSource().contains("import AppKit"))
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
