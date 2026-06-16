import XCTest
@testable import LiveSwitcher

final class RuntimeActionSurfaceTests: XCTestCase {
    func testLiveRuntimeActionSourceDoesNotExposeDeadNoopActions() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.contains("bgmPrepared"))
        XCTAssertFalse(source.contains("panicFadeCompleted"))
    }

    func testNoBGMPreparedReplacementActionAdded() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.localizedStandardContains("bgmPreparedReplacement"))
        XCTAssertFalse(source.localizedStandardContains("bgmReady"))
        XCTAssertFalse(source.localizedStandardContains("bgmDidPrepare"))
    }

    func testNoPanicFadeCompletedReplacementActionAdded() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift")

        XCTAssertFalse(source.localizedStandardContains("panicFadeCompletedReplacement"))
        XCTAssertFalse(source.localizedStandardContains("panicFadeFinished"))
        XCTAssertFalse(source.localizedStandardContains("panicFadeDidComplete"))
    }

    func testNoNewBridgeModeDomainOrPortAddedForDeadActionPruning() {
        let bridgeModes = Set(LiveRuntimeBridgeMode.allCases.map(\.rawValue))
        let domains = Set(LiveRuntimeDomain.allCases.map(\.rawValue))
        let ports = Set(LiveRuntimeEffectPortKind.allCases.map(\.rawValue))

        for rawValue in ["bgmPrepared", "panicFadeCompleted", "bgmPreparedReplacement", "panicFadeCompletedReplacement"] {
            XCTAssertFalse(bridgeModes.contains(rawValue), rawValue)
            XCTAssertFalse(domains.contains(rawValue), rawValue)
            XCTAssertFalse(ports.contains(rawValue), rawValue)
        }
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
