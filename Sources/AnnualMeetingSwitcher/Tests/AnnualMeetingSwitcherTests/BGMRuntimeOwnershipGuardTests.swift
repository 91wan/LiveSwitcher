import XCTest
@testable import LiveSwitcher

final class BGMRuntimeOwnershipGuardTests: XCTestCase {
    func testSelectedBGMPlayModeNoopsBeforeBGMOwnership() {
        var state = LiveRuntimeState()
        state.bgm.playMode = .loopAll

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedBGMPlayMode(.sequential),
            environment: .productionMediaOwned(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.bgm.playMode, .loopAll)
        XCTAssertFalse(mutation.effects.contains(.saveBGMPlayMode(.sequential)))
        XCTAssertFalse(mutation.effects.contains(.setBGMPlayMode(.sequential, generation: nil)))
    }

    func testSelectedBGMPlayModeMutatesWhenBGMOwned() {
        var state = LiveRuntimeState()
        state.bgm.playMode = .loopAll

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedBGMPlayMode(.sequential),
            environment: .productionBGMOwning(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.bgm.playMode, .sequential)
    }

    func testSelectedBGMPlayModeEmitsPersistenceEffectWhenBGMOwned() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSelectedBGMPlayMode(.loopOne),
            environment: .productionBGMOwning(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.effects.contains(.saveBGMPlayMode(.loopOne)))
        XCTAssertTrue(mutation.effects.contains(.setBGMPlayMode(.loopOne, generation: nil)))
    }

    func testAllBGMOperatorActionsHaveExplicitBGMOwnershipGuard() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/BGMRuntimeActionDispatcher.swift"
        )
        let guardedCases = [
            "case .operatorSelectedBGM",
            "case .operatorSelectedBGMPlayMode",
            "case .operatorSeekedBGMToBeginning",
            "case .operatorSeekedBGMToProgress",
            "case .operatorStoppedBGM",
            "case .operatorSelectedNextBGM",
            "case .operatorSelectedPreviousBGM",
            "case .operatorPausedBGMForPanic",
            "case .operatorResumedBGMAfterPanic"
        ]

        for marker in guardedCases {
            let body = try XCTUnwrap(caseBody(after: marker, in: source), marker)
            XCTAssertTrue(
                body.contains("guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }"),
                "\(marker) must explicitly guard .bgm ownership"
            )
        }
    }

    private func caseBody(after marker: String, in source: String) -> String? {
        guard let start = source.range(of: marker) else { return nil }
        let nextCase = source.range(of: "\n        case .", range: start.upperBound..<source.endIndex)
        let end = nextCase?.lowerBound ?? source.endIndex
        return String(source[start.lowerBound..<end])
    }
}
