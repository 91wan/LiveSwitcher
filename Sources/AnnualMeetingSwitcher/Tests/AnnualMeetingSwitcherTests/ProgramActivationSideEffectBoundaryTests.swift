import XCTest
@testable import LiveSwitcher

final class ProgramActivationSideEffectBoundaryTests: XCTestCase {
    func testDefaultSideEffectHandlersAreSafeNoOps() {
        let handlers = ProgramActivationSideEffectHandlers()
        let url = fileURL("key")

        handlers.presentKeynote(url)
        handlers.openPPTX(url)
        handlers.stopDeck()
        handlers.presentActiveDeck()
        handlers.presentInvalidDeckAlert(url)

        XCTAssertTrue(true)
    }

    func testCustomSideEffectHandlersRouteOnlyRequestedEffects() {
        var handlers = ProgramActivationSideEffectHandlers()
        let keynoteURL = fileURL("key")
        let pptxURL = fileURL("pptx")
        var events: [String] = []

        handlers.presentKeynote = { events.append("keynote:\($0.pathExtension)") }
        handlers.openPPTX = { events.append("pptx:\($0.pathExtension)") }
        handlers.stopDeck = { events.append("stopDeck") }
        handlers.presentActiveDeck = { events.append("activeDeck") }
        handlers.presentInvalidDeckAlert = { events.append("invalid:\($0.pathExtension)") }

        handlers.stopDeck()
        handlers.presentKeynote(keynoteURL)
        handlers.openPPTX(pptxURL)
        handlers.presentActiveDeck()
        handlers.presentInvalidDeckAlert(keynoteURL)

        XCTAssertEqual(events, ["stopDeck", "keynote:key", "pptx:pptx", "activeDeck", "invalid:key"])
    }

    func testMediaPlanSelectsRuntimeItemAndPerformsOnlyMediaCleanup() throws {
        let currentDeck = activeDeckItem()
        let item = mediaItem()

        let plan = try XCTUnwrap(plan(for: item, currentItem: currentDeck, queuedItems: [item]))

        XCTAssertEqual(plan.runtimeSelection, .queued(item.id))
        XCTAssertEqual(plan.preSelectionEffects, [.stopDeck])
        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .resetMutedMediaStartupFlag])
    }

    func testValidPresentationPlansUseSpecificPresentationEffectsAfterHTMLClear() throws {
        let keynote = keynoteItem()
        let pptx = pptxItem()

        let keynotePlan = try XCTUnwrap(plan(for: keynote, queuedItems: [keynote], isValidDeckDocument: { _, _ in true }))
        let pptxPlan = try XCTUnwrap(plan(for: pptx, queuedItems: [pptx], isValidDeckDocument: { _, _ in true }))

        XCTAssertEqual(keynotePlan.runtimeSelection, .queued(keynote.id))
        XCTAssertEqual(keynotePlan.postSelectionEffects, [.clearHTML, .presentKeynote(keynote.sourceURL!)])
        XCTAssertEqual(pptxPlan.runtimeSelection, .queued(pptx.id))
        XCTAssertEqual(pptxPlan.postSelectionEffects, [.clearHTML, .openPPTX(pptx.sourceURL!)])
    }

    func testInvalidPresentationPlansAbortBeforeRuntimeSelection() throws {
        let keynote = keynoteItem()
        let pptx = pptxItem()

        let keynotePlan = try XCTUnwrap(plan(for: keynote, isValidDeckDocument: { _, _ in false }))
        let pptxPlan = try XCTUnwrap(plan(for: pptx, isValidDeckDocument: { _, _ in false }))

        XCTAssertNil(keynotePlan.runtimeSelection)
        XCTAssertEqual(keynotePlan.preSelectionEffects, [.presentInvalidDeckAlert(keynote.sourceURL!)])
        XCTAssertEqual(keynotePlan.postSelectionEffects, [])
        XCTAssertTrue(keynotePlan.abortsBeforeSelection)
        XCTAssertNil(pptxPlan.runtimeSelection)
        XCTAssertEqual(pptxPlan.preSelectionEffects, [.presentInvalidDeckAlert(pptx.sourceURL!)])
        XCTAssertEqual(pptxPlan.postSelectionEffects, [])
        XCTAssertTrue(pptxPlan.abortsBeforeSelection)
    }

    func testHTMLAndActiveDeckPlansKeepTheirSideEffectsNarrow() throws {
        let html = htmlItem()
        let activeDeck = activeDeckItem()

        let htmlPlan = try XCTUnwrap(plan(for: html, queuedItems: [html]))
        let activeDeckPlan = try XCTUnwrap(plan(for: activeDeck, queuedItems: [activeDeck]))

        XCTAssertEqual(htmlPlan.runtimeSelection, .queued(html.id))
        XCTAssertEqual(htmlPlan.preSelectionEffects, [])
        XCTAssertEqual(htmlPlan.postSelectionEffects, [.openHTML(html.sourceURL!)])
        XCTAssertEqual(activeDeckPlan.runtimeSelection, .queued(activeDeck.id))
        XCTAssertEqual(activeDeckPlan.postSelectionEffects, [.clearHTML, .presentActiveDeck])
    }

    func testNonActivatableItemsCreateNoActivationPlan() {
        XCTAssertNil(plan(for: .agendaMarker(title: "Break")))
        XCTAssertNil(plan(for: ProgramItem(title: "Unsupported", subtitle: "TXT")))
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

    private func mediaItem() -> ProgramItem {
        ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: fileURL("mp4"))
    }

    private func htmlItem() -> ProgramItem {
        ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: fileURL("html"))
    }

    private func keynoteItem() -> ProgramItem {
        ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: fileURL("key"))
    }

    private func pptxItem() -> ProgramItem {
        ProgramItem(title: "Slides", subtitle: "PPTX", sourceURL: fileURL("pptx"))
    }

    private func activeDeckItem() -> ProgramItem {
        ProgramItem(title: "Active Deck", subtitle: "KEY")
    }

    private func fileURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }
}
