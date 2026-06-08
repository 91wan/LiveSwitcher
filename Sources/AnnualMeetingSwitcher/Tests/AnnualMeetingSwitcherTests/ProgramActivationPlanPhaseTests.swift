import XCTest
@testable import LiveSwitcher

final class ProgramActivationPlanPhaseTests: XCTestCase {
    func testInvalidDeckPlanAbortsBeforeSelection() {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let plan = ProgramActivationPlan(
            item: keynoteItem(url: url),
            runtimeSelection: nil,
            preSelectionEffects: [.presentInvalidDeckAlert(url)],
            postSelectionEffects: []
        )

        XCTAssertTrue(plan.abortsBeforeSelection)
    }

    func testInvalidDeckPlanHasNoRuntimeSelection() {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let plan = ProgramActivationPlan(
            item: keynoteItem(url: url),
            runtimeSelection: nil,
            preSelectionEffects: [.presentInvalidDeckAlert(url)],
            postSelectionEffects: []
        )

        XCTAssertNil(plan.runtimeSelection)
    }

    func testMediaPlanHasClearHTMLAndResetMutedStartupFlag() {
        let item = mediaItem()
        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .queued(item.id),
            preSelectionEffects: [],
            postSelectionEffects: [.clearHTML, .resetMutedMediaStartupFlag]
        )

        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .resetMutedMediaStartupFlag])
    }

    func testKeynotePlanHasClearHTMLThenPresentKeynote() {
        let url = URL(fileURLWithPath: "/tmp/deck.key")
        let plan = ProgramActivationPlan(
            item: keynoteItem(url: url),
            runtimeSelection: .detached(keynoteItem(url: url)),
            preSelectionEffects: [],
            postSelectionEffects: [.clearHTML, .presentKeynote(url)]
        )

        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .presentKeynote(url)])
    }

    func testPPTXPlanHasClearHTMLThenOpenPPTX() {
        let url = URL(fileURLWithPath: "/tmp/deck.pptx")
        let item = ProgramItem(title: "Slides", subtitle: "PPTX", sourceURL: url)
        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .detached(item),
            preSelectionEffects: [],
            postSelectionEffects: [.clearHTML, .openPPTX(url)]
        )

        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .openPPTX(url)])
    }

    func testHTMLPlanHasOpenHTMLWithoutClearHTML() {
        let url = URL(fileURLWithPath: "/tmp/page.html")
        let item = ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: url)
        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .detached(item),
            preSelectionEffects: [],
            postSelectionEffects: [.openHTML(url)]
        )

        XCTAssertEqual(plan.postSelectionEffects, [.openHTML(url)])
        XCTAssertFalse(plan.postSelectionEffects.contains(.clearHTML))
    }

    func testActiveDeckPlanHasClearHTMLThenPresentActiveDeck() {
        let item = ProgramItem(title: "Active", subtitle: "KEY")
        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .detached(item),
            preSelectionEffects: [],
            postSelectionEffects: [.clearHTML, .presentActiveDeck]
        )

        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .presentActiveDeck])
    }

    func testStopDeckIsPreSelectionEffectOnly() {
        let item = mediaItem()
        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .queued(item.id),
            preSelectionEffects: [.stopDeck],
            postSelectionEffects: [.clearHTML, .resetMutedMediaStartupFlag]
        )

        XCTAssertEqual(plan.preSelectionEffects, [.stopDeck])
        XCTAssertFalse(plan.postSelectionEffects.contains { effect in
            if case .presentActiveDeck = effect { return false }
            return String(describing: effect) == "stopDeck"
        })
    }

    func testProgramActivationPlanDoesNotContainShouldStopCurrentDeckPresentation() throws {
        let source = try planSource()

        XCTAssertFalse(source.contains("shouldStopCurrentDeckPresentation"))
    }

    func testProgramActivationPlanDoesNotContainShouldClearHTML() throws {
        let source = try planSource()

        XCTAssertFalse(source.contains("shouldClearHTML"))
    }

    func testProgramActivationPlanDoesNotContainSingleSideEffectField() throws {
        let source = try planSource()

        XCTAssertFalse(source.contains("var sideEffect"))
    }

    private func planSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramActivationPlan.swift")
    }

    private func mediaItem() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
    }

    private func keynoteItem(url: URL) -> ProgramItem {
        ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: url)
    }
}
