import XCTest
@testable import LiveSwitcher

final class RuntimeSnapshotOwnershipBoundaryTests: XCTestCase {
    func testSyncMediaIntoRuntimeSnapshotExists() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertTrue(source.contains("syncMediaIntoRuntimeSnapshot"))
    }

    func testRuntimeBackedMediaIsPlayingForSnapshotExists() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertTrue(source.contains("runtimeBackedMediaIsPlayingForSnapshot"))
    }

    func testRuntimeBackedCurrentProgramIsMediaSourceForSnapshotExists() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertTrue(source.contains("runtimeBackedCurrentProgramIsMediaSourceForSnapshot"))
    }

    func testMakeRuntimeStateSnapshotDoesNotWriteMediaFieldsDirectly() throws {
        let source = try runtimeSnapshotSource()
        let body = try XCTUnwrap(functionBody(named: "makeRuntimeStateSnapshot", in: source))

        XCTAssertFalse(body.contains("state.media.loadedURL = avCoordinator.currentURL"))
        XCTAssertFalse(body.contains("state.media.isPlaying = avCoordinator.isPlaying"))
        XCTAssertFalse(body.contains("state.media.currentTime = avCoordinator.currentTime"))
        XCTAssertFalse(body.contains("state.media.duration = avCoordinator.duration"))
        XCTAssertTrue(body.contains("syncMediaIntoRuntimeSnapshot(&state)"))
    }

    func testRuntimeSnapshotSourceDoesNotUseAVCoordinatorPlayingForAudioRoutingContext() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertFalse(source.contains("isMediaPlaying: avCoordinator.isPlaying"))
    }

    func testRuntimeSnapshotSourceDoesNotUseFacadeCurrentProgramMediaSourceForAudioRoutingContext() throws {
        let source = try runtimeSnapshotSource()

        XCTAssertFalse(source.contains("isCurrentProgramMediaSource: currentProgramIsMediaSource"))
    }

    func testNoSnapshotBridgeModeDomainOrPortAdded() {
        let forbidden = ["mediaSnapshotOwned", "audioSnapshotOwned", "programSnapshotOwned"]
        let bridgeModes = Set(LiveRuntimeBridgeMode.allCases.map(\.rawValue))
        let domains = Set(LiveRuntimeDomain.allCases.map(\.rawValue))
        let ports = Set(LiveRuntimeEffectPortKind.allCases.map(\.rawValue))

        for rawValue in forbidden {
            XCTAssertFalse(bridgeModes.contains(rawValue), rawValue)
            XCTAssertFalse(domains.contains(rawValue), rawValue)
            XCTAssertFalse(ports.contains(rawValue), rawValue)
        }
    }

    private func runtimeSnapshotSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")
    }

    private func functionBody(named functionName: String, in source: String) -> String? {
        guard let nameRange = source.range(of: "func \(functionName)") else { return nil }
        guard let openingBrace = source[nameRange.lowerBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = openingBrace
        while index < source.endIndex {
            if source[index] == "{" {
                depth += 1
            } else if source[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[openingBrace...index])
                }
            }
            index = source.index(after: index)
        }
        return nil
    }
}
