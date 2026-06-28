import XCTest
@testable import LiveSwitcher

@MainActor
final class LivePreflightPresentationReadinessTests: XCTestCase {
    func testPPTModeUsesManualReviewActionWithoutMutatingState() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.isPageInterceptEnabled = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let ppt = livePreflightCheck("controls.ppt", in: checks)

        XCTAssertEqual(ppt.group, .controls)
        XCTAssertEqual(ppt.status, .warn)
        XCTAssertEqual(ppt.actionKind, .manualReview)
        XCTAssertEqual(ppt.actionLabel, "人工复核")

        let beforeSnapshot = viewModel.livePreflightSnapshot
        XCTAssertFalse(viewModel.performLivePreflightAction(.manualReview))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
    }

    func testPPTModeWarnsWhenEnabledWithoutPageableProgram() {
        var snapshot = livePreflightReadySnapshot()
        snapshot.currentProgramSource = "Media"
        snapshot.isPageInterceptEnabled = true

        let ppt = livePreflightCheck("controls.ppt", in: LivePreflightCheck.build(from: snapshot))

        XCTAssertEqual(ppt.status, .warn)
        XCTAssertEqual(ppt.actionKind, .manualReview)
        XCTAssertTrue(ppt.message.localizedStandardContains("当前节目不是可翻页信号源"))
    }

    func testPPTModePassesWhenEnabledForPageableProgram() {
        for source in ["HTML", "Keynote", "PPTX", "Active Keynote Deck"] {
            var snapshot = livePreflightReadySnapshot()
            snapshot.currentProgramSource = source
            snapshot.isPageInterceptEnabled = true

            let ppt = livePreflightCheck("controls.ppt", in: LivePreflightCheck.build(from: snapshot))

            XCTAssertEqual(ppt.status, .pass, source)
        }
    }

    func testPPTModeWarnsWhenDeckProgramNeedsPageControlButModeIsOff() {
        for source in ["Keynote", "PPTX", "Active Keynote Deck"] {
            var snapshot = livePreflightReadySnapshot()
            snapshot.currentProgramSource = source
            snapshot.isPageInterceptEnabled = false

            let ppt = livePreflightCheck("controls.ppt", in: LivePreflightCheck.build(from: snapshot))

            XCTAssertEqual(ppt.status, .warn, source)
            XCTAssertEqual(ppt.actionKind, .manualReview)
            XCTAssertTrue(ppt.message.localizedStandardContains("当前载入演示信号源"))
        }
    }
}
