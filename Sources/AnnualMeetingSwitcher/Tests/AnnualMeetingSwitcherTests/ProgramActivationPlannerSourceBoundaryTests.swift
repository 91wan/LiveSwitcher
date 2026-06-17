import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationPlannerSourceBoundaryTests: XCTestCase {
    func testProgramActivationPlannerUsesRuntimeCurrentProgramWhenProgramSelectionOwned() throws {
        let runtimeCurrent = activeDeck("Runtime Deck")
        let staleFacadeCurrent = mediaItem("Facade Video")
        let next = mediaItem("Next")
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [runtimeCurrent, next],
            runtimeCurrent: runtimeCurrent,
            facadeItems: [staleFacadeCurrent, next],
            facadeCurrent: staleFacadeCurrent
        )

        viewModel.switchToProgram(next)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertEqual(plan.preSelectionEffects, [.stopDeck])
    }

    func testProgramActivationPlannerUsesFacadeCurrentProgramBeforeProgramSelectionOwnership() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains("? runtime.state.program.effectiveCurrentItem"))
        XCTAssertTrue(source.contains(": currentProgramItem"))
    }

    func testProgramActivationPlannerUsesRuntimeQueueWhenProgramQueueOwned() throws {
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

    func testProgramActivationPlannerUsesFacadeQueueBeforeProgramQueueOwnership() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains("? runtime.state.program.items"))
        XCTAssertTrue(source.contains(": programItems"))
    }

    func testProgramActivationCanonicalizesQueuedItemFromRuntimeQueue() throws {
        let id = UUID()
        let staleURL = try temporaryFile(ext: "mp4", contents: "stale")
        let canonicalURL = try temporaryFile(ext: "mp4", contents: "canonical")
        let stale = ProgramItem(id: id, title: "Stale", subtitle: "VIDEO", sourceURL: staleURL)
        let canonical = ProgramItem(id: id, title: "Canonical", subtitle: "VIDEO", sourceURL: canonicalURL)
        let viewModel = makeViewModel(
            bridgeMode: .programActivationOwned,
            runtimeItems: [canonical],
            facadeItems: [stale]
        )

        viewModel.switchToProgram(stale)

        let plan = try XCTUnwrap(recordedActivationPlan(in: viewModel))
        XCTAssertEqual(plan.item, canonical)
        XCTAssertEqual(plan.runtimeSelection, .queued(id))
    }

    func testProgramActivationUsesDetachedItemWhenNotPresentInRuntimeQueue() throws {
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

    func testRuntimeBackedActivationPlanningHelpersExist() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains("runtimeBackedCurrentProgramForActivationPlanning"))
        XCTAssertTrue(source.contains("runtimeBackedProgramItemsForActivationPlanning"))
        XCTAssertTrue(source.contains("runtimeBackedProgramItemForActivationPlanning"))
    }
}

@MainActor
func makeViewModel(
    bridgeMode: LiveRuntimeBridgeMode,
    runtimeItems: [ProgramItem],
    runtimeCurrent: ProgramItem? = nil,
    facadeItems: [ProgramItem],
    facadeCurrent: ProgramItem? = nil
) -> SwitcherViewModel {
    var state = LiveRuntimeState()
    state.program.items = runtimeItems
    state.program.currentID = runtimeCurrent?.id
    state.program.currentDetachedItem = nil
    state.program.currentSwitchedAt = runtimeCurrent == nil ? nil : Date(timeIntervalSince1970: 100)
    let programActivation = ClosureProgramActivationPort()
    let runtime = LiveRuntimeStore(
        initialState: state,
        effectRunner: LiveRuntimeEffectRunner(
            recordsOnly: false,
            programActivation: programActivation
        ),
        environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
    )
    let viewModel = SwitcherViewModel(
        loadPersistedData: false,
        enableSystemVolumeObserver: false,
        runtime: runtime
    )
    capturedActivationPlans[ObjectIdentifier(viewModel)] = []
    programActivation.executeHandler = { [weak viewModel] _, plan, _ in
        guard let viewModel else { return }
        capturedActivationPlans[ObjectIdentifier(viewModel), default: []].append(plan)
    }
    viewModel.applyProgramQueueProjectionFromRuntime(facadeItems)
    viewModel.applyCurrentProgramProjectionFromRuntime(
        facadeCurrent,
        switchedAt: facadeCurrent == nil ? nil : Date(timeIntervalSince1970: 10)
    )
    return viewModel
}

@MainActor
func recordedActivationPlan(in viewModel: SwitcherViewModel) -> ProgramActivationPlan? {
    if let plan = capturedActivationPlans[ObjectIdentifier(viewModel)]?.last {
        return plan
    }
    return viewModel.runtime.recordedEffects.compactMap { effect in
        if case .executeProgramActivation(_, let plan) = effect {
            return plan
        }
        return nil
    }.last
}

@MainActor
private var capturedActivationPlans: [ObjectIdentifier: [ProgramActivationPlan]] = [:]

func mediaItem(_ title: String, id: UUID = UUID(), url: URL? = nil) -> ProgramItem {
    let sourceURL = url ?? autoCreatedTemporaryFile(ext: "mp4")
    return ProgramItem(
        id: id,
        title: title,
        subtitle: "VIDEO",
        sourceURL: sourceURL
    )
}

func htmlItem(_ title: String, id: UUID = UUID(), url: URL? = nil) -> ProgramItem {
    let sourceURL = url ?? autoCreatedTemporaryFile(ext: "html")
    return ProgramItem(
        id: id,
        title: title,
        subtitle: "HTML",
        sourceURL: sourceURL
    )
}

func activeDeck(_ title: String, id: UUID = UUID()) -> ProgramItem {
    ProgramItem(id: id, title: title, subtitle: "KEY (活动)", sourceURL: nil)
}

func temporaryFile(ext: String, contents: String = "fixture") throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext)
    try Data(contents.utf8).write(to: url)
    return url
}

private func autoCreatedTemporaryFile(ext: String) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(ext)
    try? Data("fixture".utf8).write(to: url)
    return url
}
