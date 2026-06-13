import XCTest
import AppKit
@testable import LiveSwitcher

@MainActor
final class ViewModelPanicTransitionBehaviorTests: XCTestCase {
    func testActivatePanicCapturesPolicySnapshot() throws {
        let source = try panicSource()

        XCTAssertTrue(source.contains("PanicTransitionPolicy.snapshot"))
    }

    func testActivatePanicPausesMediaImmediatelyWhenPolicyAllows() throws {
        let viewModel = makeViewModel()
        let program = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: try temporaryURL(ext: "mp4"))
        defer { try? FileManager.default.removeItem(at: program.sourceURL!) }

        viewModel.switchToProgram(program)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertGreaterThanOrEqual(mediaPauseEffectCount(in: viewModel), 1)
    }

    func testActivatePanicDoesNotPauseMediaWhenCurrentProgramChanged() {
        let program = mediaProgram(title: "Opening")
        let different = mediaProgram(title: "Awards")
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: program.id,
            wasMediaPlaying: true,
            currentBGMID: nil,
            wasBGMPlaying: false
        )

        XCTAssertFalse(
            PanicTransitionPolicy.shouldPauseMediaForActivation(
                snapshot: snapshot,
                currentProgram: different
            )
        )
    }

    func testActivatePanicSchedulesBGMPauseAfterFadeWhenPolicyAllows() throws {
        let source = try panicSource()

        XCTAssertTrue(source.contains("cleanupBag.panicAudioPauseTask = Task"))
        XCTAssertTrue(source.contains("PanicTransitionPolicy.shouldPauseBGMAfterFadeForActivation"))
    }

    func testActivatePanicDoesNotPauseBGMImmediatelyBeforeFade() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        startBGM(bgm, in: viewModel)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testActivatePanicAppliesPanicAudioRoutingBeforeDelayedBGMStop() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        startBGM(bgm, in: viewModel)

        viewModel.togglePanicMode()

        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .panicChanged)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testDeactivatePanicCancelsDelayedBGMPauseTask() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0.05
        startBGM(bgm, in: viewModel)

        viewModel.togglePanicMode()
        viewModel.togglePanicMode()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testDeactivatePanicResumesMediaOnlyWhenPolicyAllows() throws {
        let viewModel = makeViewModel()
        let program = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: try temporaryURL(ext: "mp4"))
        defer { try? FileManager.default.removeItem(at: program.sourceURL!) }

        viewModel.switchToProgram(program)
        viewModel.togglePanicMode()
        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertGreaterThanOrEqual(mediaPlayEffectCount(in: viewModel), 1)
    }

    func testDeactivatePanicResumesBGMOnlyWhenPolicyAllows() {
        let viewModel = makeViewModel()
        let bgm = bgmItem(title: "Walk-in")
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [bgm]
        viewModel.toggleBGM(bgm)

        viewModel.togglePanicMode()
        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertGreaterThanOrEqual(playBGMEffectCount(in: viewModel), 1)
    }

    func testDeactivatePanicDoesNotResumeDifferentBGM() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [first, second]
        startBGM(first, in: viewModel)

        viewModel.togglePanicMode()
        viewModel.toggleBGM(second)
        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
    }

    func testTogglePanicRecordsSupportEventOnce() {
        let viewModel = makeViewModel()
        let before = supportEventCount(in: viewModel)

        viewModel.togglePanicMode()

        XCTAssertEqual(supportEventCount(in: viewModel), before + 1)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.programActivationSideEffects.presentKeynote = { _ in }
        viewModel.programActivationSideEffects.openPPTX = { _ in }
        viewModel.programActivationSideEffects.presentActiveDeck = {}
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }
        viewModel.programActivationSideEffects.stopDeck = {}
        return viewModel
    }

    private func mediaProgram(title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MP4", sourceURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp4"))
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func temporaryURL(ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: Data("fixture".utf8))
        return url
    }

    private func startBGM(_ bgm: BGMItem, in viewModel: SwitcherViewModel) {
        if !viewModel.bgmItems.contains(where: { $0.id == bgm.id }) {
            viewModel.bgmItems.append(bgm)
        }
        viewModel.toggleBGM(bgm)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    private func mediaPauseEffectCount(in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.recordedEffects.filter {
            if case .pauseMedia = $0 { return true }
            return false
        }.count
    }

    private func mediaPlayEffectCount(in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.recordedEffects.filter {
            if case .playMedia = $0 { return true }
            return false
        }.count
    }

    private func playBGMEffectCount(in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.recordedEffects.filter {
            if case .playBGM = $0 { return true }
            return false
        }.count
    }

    private func supportEventCount(in viewModel: SwitcherViewModel) -> Int {
        viewModel.supportEvents.filter { $0.kind == .panicModeChanged }.count
    }

    private func panicSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")
    }
}
