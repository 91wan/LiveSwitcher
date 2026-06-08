import XCTest
@testable import LiveSwitcher

final class ProgramActivationSideEffectWiringTests: XCTestCase {
    func testConfigureDefaultProgramActivationSideEffectsExists() throws {
        let source = try repositorySource(wiringPath)

        XCTAssertTrue(source.contains("func configureDefaultProgramActivationSideEffects()"))
    }

    func testDefaultSideEffectWiringLivesInProgramActivationSideEffectWiringFile() throws {
        let source = try repositorySource(wiringPath)

        XCTAssertTrue(source.contains("programActivationSideEffects.presentKeynote"))
        XCTAssertTrue(source.contains("programActivationSideEffects.openPPTX"))
        XCTAssertTrue(source.contains("programActivationSideEffects.stopDeck"))
        XCTAssertTrue(source.contains("programActivationSideEffects.presentActiveDeck"))
        XCTAssertTrue(source.contains("programActivationSideEffects.presentInvalidDeckAlert"))
    }

    func testViewModelInitCallsConfigureDefaultProgramActivationSideEffects() throws {
        let source = try repositorySource(viewModelPath)

        XCTAssertTrue(source.contains("configureDefaultProgramActivationSideEffects()"))
    }

    func testViewModelInitDoesNotCallConfigureDefaultActionHandlers() throws {
        let source = try repositorySource(viewModelPath)

        XCTAssertFalse(source.contains("configureDefaultActionHandlers()"))
    }

    func testDefaultWiringDoesNotWireMediaSeekHandlers() throws {
        let source = try repositorySource(wiringPath)

        XCTAssertFalse(source.contains("programSeekToStart"))
        XCTAssertFalse(source.contains("programRestartFromBeginning"))
        XCTAssertFalse(source.contains("programSeekToEnd"))
        XCTAssertFalse(source.contains("avCoordinator.seekToBeginning()"))
        XCTAssertFalse(source.contains("avCoordinator.restartFromBeginning"))
        XCTAssertFalse(source.contains("avCoordinator.seekToEnd()"))
    }

    func testDefaultWiringUsesExistingPresentationAutomationMethods() throws {
        let source = try repositorySource(wiringPath)

        XCTAssertTrue(source.contains("openAndPresentKeynote(url: url)"))
        XCTAssertTrue(source.contains("openPPTXWithKeynote(url: url)"))
        XCTAssertTrue(source.contains("stopDeckPresentation()"))
        XCTAssertTrue(source.contains("presentFrontKeynoteDocument()"))
    }

    func testDefaultWiringUsesExistingInvalidDeckAlertMethod() throws {
        let source = try repositorySource(wiringPath)

        XCTAssertTrue(source.contains("presentInvalidDeckAlert(for: url)"))
    }

    func testActionHandlerWiringFileDoesNotContainActiveWiring() throws {
        guard let source = try optionalRepositorySource(actionHandlerWiringPath) else { return }

        XCTAssertFalse(source.contains("func configureDefaultActionHandlers()"))
        XCTAssertFalse(source.contains("programActivationSideEffects."))
        XCTAssertFalse(source.contains("avCoordinator.seekToBeginning"))
        XCTAssertFalse(source.contains("avCoordinator.restartFromBeginning"))
        XCTAssertFalse(source.contains("avCoordinator.seekToEnd"))
    }

    private var wiringPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationSideEffectWiring.swift"
    }

    private var actionHandlerWiringPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ActionHandlerWiring.swift"
    }

    private var viewModelPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift"
    }
}
