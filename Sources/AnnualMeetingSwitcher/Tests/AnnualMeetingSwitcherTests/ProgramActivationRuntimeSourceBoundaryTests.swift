import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationRuntimeSourceBoundaryTests: XCTestCase {
    func testSwitchToProgramBuildsQueuedRuntimeSelectionWhenItemExistsInRuntimeQueueEvenIfFacadeQueueMissing() throws {
        let item = mediaItem("Runtime Queued")
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [item],
            facadeItems: []
        )

        viewModel.switchToProgram(item)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertEqual(plan.runtimeSelection, .queued(item.id))
    }

    func testSwitchToProgramBuildsDetachedRuntimeSelectionWhenItemMissingFromRuntimeQueue() throws {
        let item = mediaItem("Detached")
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [],
            facadeItems: [item]
        )

        viewModel.switchToProgram(item)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertEqual(plan.runtimeSelection, .detached(item))
    }

    func testSwitchToProgramUsesRuntimeCurrentDeckForPreSelectionStopDeckWhenProgramSelectionOwned() throws {
        let runtimeCurrent = activeDeck("Runtime Deck")
        let next = mediaItem("Next")
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [runtimeCurrent, next],
            runtimeCurrent: runtimeCurrent,
            facadeItems: [next],
            facadeCurrent: nil
        )

        viewModel.switchToProgram(next)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertEqual(plan.preSelectionEffects, [.stopDeck])
    }

    func testSwitchToProgramDoesNotUseStaleFacadeCurrentDeckWhenProgramSelectionOwned() throws {
        let staleFacadeCurrent = activeDeck("Facade Deck")
        let next = mediaItem("Next")
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [next],
            runtimeCurrent: nil,
            facadeItems: [staleFacadeCurrent, next],
            facadeCurrent: staleFacadeCurrent
        )

        viewModel.switchToProgram(next)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertFalse(plan.preSelectionEffects.contains(.stopDeck))
    }

    func testSwitchToProgramUsesFacadeCurrentDeckBeforeProgramSelectionOwnership() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains(": currentProgramItem"))
    }

    func testSwitchToProgramUsesRuntimeCanonicalItemURLWhenRuntimeQueueOwned() throws {
        let id = UUID()
        let staleURL = try temporaryFile(ext: "html", contents: "stale")
        let canonicalURL = try temporaryFile(ext: "html", contents: "canonical")
        let stale = ProgramItem(id: id, title: "Stale HTML", subtitle: "HTML", sourceURL: staleURL)
        let canonical = ProgramItem(id: id, title: "Canonical HTML", subtitle: "HTML", sourceURL: canonicalURL)
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [canonical],
            facadeItems: [stale]
        )

        viewModel.switchToProgram(stale)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertEqual(plan.item, canonical)
        XCTAssertEqual(plan.postSelectionEffects, [.openHTML(canonicalURL)])
    }

    func testSwitchToProgramStillDispatchesRuntimeActivationRequest() {
        let item = mediaItem("Runtime Queued")
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [item],
            facadeItems: []
        )

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRequestedProgramActivation" })
    }

    func testReadinessConfirmationUsesRuntimeCanonicalItemWhenProgramQueueOwned() throws {
        let id = UUID()
        let staleURL = URL(fileURLWithPath: "/tmp/missing-\(UUID()).mp4")
        let canonicalURL = try temporaryFile(ext: "mp4", contents: "canonical")
        let stale = ProgramItem(id: id, title: "Stale", subtitle: "VIDEO", sourceURL: staleURL)
        let canonical = ProgramItem(id: id, title: "Canonical", subtitle: "VIDEO", sourceURL: canonicalURL)
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [canonical],
            facadeItems: [stale]
        )

        viewModel.switchToProgramAfterReadinessConfirmation(stale)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertEqual(plan.item, canonical)
    }

    func testReadinessConfirmationUsesFacadeItemBeforeProgramQueueOwnership() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains(": item"))
    }

    func testSwitchToProgramAtUsesRuntimeQueueWhenProgramQueueOwned() throws {
        let item = mediaItem("Runtime Indexed")
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [item],
            facadeItems: []
        )

        viewModel.switchToProgram(at: 0)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertEqual(plan.item, item)
        XCTAssertEqual(plan.runtimeSelection, .queued(item.id))
    }

    func testSwitchToProgramAtUsesFacadeQueueBeforeProgramQueueOwnership() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains(": programItems"))
    }

    func testSwitchToProgramAtNoopsForOutOfRangeRuntimeQueueIndex() {
        let item = mediaItem("Runtime Indexed")
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [item],
            facadeItems: []
        )

        viewModel.switchToProgram(at: 1)

        XCTAssertNil(recordedActivationPlan(in: viewModel))
    }

    func testAgendaReminderActionUsesRuntimeQueueWhenProgramQueueOwned() throws {
        let item = mediaItem("Runtime Prompt")
        let prompt = AgendaReminderPrompt(
            itemID: item.id,
            title: item.title,
            scheduledStartAt: Date(timeIntervalSince1970: 100),
            kind: .playableProgram
        )
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [item],
            facadeItems: []
        )

        viewModel.handleAgendaReminderAction(prompt)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertEqual(plan.item, item)
        XCTAssertTrue(viewModel.agendaReminderAcknowledgedItemIDs.contains(item.id))
    }

    func testAgendaReminderMarkerActionAcknowledgesWithoutSwitching() {
        let marker = ProgramItem.agendaMarker(
            title: "Tea Break",
            scheduledStartAt: Date(timeIntervalSince1970: 100)
        )
        let prompt = AgendaReminderPrompt(
            itemID: marker.id,
            title: marker.title,
            scheduledStartAt: Date(timeIntervalSince1970: 100),
            kind: .marker
        )
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [marker],
            facadeItems: []
        )

        viewModel.handleAgendaReminderAction(prompt)

        XCTAssertTrue(viewModel.agendaReminderAcknowledgedItemIDs.contains(marker.id))
        XCTAssertNil(recordedActivationPlan(in: viewModel))
    }

    func testAgendaReminderActionUsesFacadeQueueBeforeProgramQueueOwnership() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains(": programItems"))
    }

    func testAgendaReminderActionStillRecordsAcknowledgedIDWhenRuntimeItemMissing() {
        let missingID = UUID()
        let prompt = AgendaReminderPrompt(
            itemID: missingID,
            title: "Missing",
            scheduledStartAt: Date(timeIntervalSince1970: 100),
            kind: .playableProgram
        )
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [],
            facadeItems: []
        )

        viewModel.handleAgendaReminderAction(prompt)

        XCTAssertTrue(viewModel.agendaReminderAcknowledgedItemIDs.contains(missingID))
        XCTAssertNil(recordedActivationPlan(in: viewModel))
    }

    func testSwitchToMissingFileDoesNotDispatchActivationRequest() {
        let missing = ProgramItem(
            title: "Missing",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/missing-\(UUID()).mp4")
        )
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [missing],
            facadeItems: [missing]
        )

        viewModel.switchToProgram(missing)

        XCTAssertNil(recordedActivationPlan(in: viewModel))
    }

    func testSwitchToProgramChecksSourceAvailabilityOnRuntimeCanonicalItem() throws {
        let id = UUID()
        let staleURL = try temporaryFile(ext: "mp4", contents: "stale")
        let missingCanonicalURL = URL(fileURLWithPath: "/tmp/missing-\(UUID()).mp4")
        let stale = ProgramItem(id: id, title: "Stale", subtitle: "VIDEO", sourceURL: staleURL)
        let canonical = ProgramItem(id: id, title: "Canonical", subtitle: "VIDEO", sourceURL: missingCanonicalURL)
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [canonical],
            facadeItems: [stale]
        )

        viewModel.switchToProgram(stale)

        XCTAssertNil(recordedActivationPlan(in: viewModel))
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .programItemFileMissing })
    }
}
