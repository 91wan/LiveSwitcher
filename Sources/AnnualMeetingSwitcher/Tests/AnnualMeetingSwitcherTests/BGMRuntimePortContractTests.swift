import XCTest
@testable import LiveSwitcher

final class BGMRuntimePortContractTests: XCTestCase {
    func testBGMPlaybackPortRequiresSeekAndPlayModeMethods() throws {
        let source = try sourceText("Runtime/LiveRuntimeEffect.swift")
        let protocolBody = try body(named: "BGMPlaybackPort", prefix: "protocol", in: source)

        [
            "func prepare(item: BGMItem, generation: Int)",
            "func play(generation: Int)",
            "func pause(generation: Int)",
            "func stop(fade: TimeInterval, generation: Int)",
            "func setVolume(_ volume: Float, fade: TimeInterval, generation: Int)",
            "func seekToBeginning(generation: Int)",
            "func seek(toProgress progress: Double, generation: Int)",
            "func setPlayMode(_ playMode: BGMPlayMode, generation: Int?)"
        ].forEach { requirement in
            XCTAssertTrue(protocolBody.contains(requirement), "Missing required BGM port method: \(requirement)")
        }
    }

    func testProductionClosureBGMPlaybackPortImplementsEveryMethod() throws {
        let source = try sourceText("Runtime/LiveRuntimeClosurePorts.swift")
        let closurePortBody = try body(named: "ClosureBGMPlaybackPort", prefix: "final class", in: source)

        [
            "func prepare(item: BGMItem, generation: Int)",
            "func play(generation: Int)",
            "func pause(generation: Int)",
            "func stop(fade: TimeInterval, generation: Int)",
            "func setVolume(_ volume: Float, fade: TimeInterval, generation: Int)",
            "func seekToBeginning(generation: Int)",
            "func seek(toProgress progress: Double, generation: Int)",
            "func setPlayMode(_ playMode: BGMPlayMode, generation: Int?)"
        ].forEach { implementation in
            XCTAssertTrue(closurePortBody.contains(implementation), "Missing production BGM port method: \(implementation)")
        }
    }

    func testAllBGMEffectsHaveBGMRequiredBridgeDomain() {
        let item = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))

        [
            LiveRuntimeEffect.prepareBGM(item, generation: 1),
            .playBGM(generation: 1),
            .pauseBGM(generation: 1),
            .stopBGM(fade: 0.3, generation: 1),
            .setBGMVolume(0.5, fade: 0.1, generation: 1),
            .seekBGMToBeginning(generation: 1),
            .seekBGMToProgress(0.5, generation: 1),
            .setBGMPlayMode(.loopOne, generation: 1),
            .startBGMTimer(generation: 1),
            .stopBGMTimer(generation: 1),
            .saveBGMPlayMode(.sequential)
        ].forEach { effect in
            XCTAssertEqual(effect.requiredBridgeDomain, .bgm, "\(effect) should require BGM domain")
        }
    }

    func testNoDefaultNoOpBGMPlaybackPortMethodsRemain() throws {
        let source = try sourceText("Runtime/LiveRuntimeEffect.swift")

        XCTAssertFalse(source.contains("extension BGMPlaybackPort"))
        XCTAssertFalse(source.contains("func seekToBeginning(generation: Int) {}"))
        XCTAssertFalse(source.contains("func seek(toProgress progress: Double, generation: Int) {}"))
        XCTAssertFalse(source.contains("func setPlayMode(_ playMode: BGMPlayMode, generation: Int?) {}"))
    }

    private func body(named name: String, prefix: String, in source: String) throws -> String {
        guard let start = source.range(of: "\(prefix) \(name)") else {
            XCTFail("\(prefix) \(name) not found")
            return ""
        }
        guard let bodyStart = source[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("\(name) body not found")
            return ""
        }
        var depth = 0
        var index = bodyStart
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[start.lowerBound...index])
                }
            }
            index = source.index(after: index)
        }
        XCTFail("\(name) body was not closed")
        return ""
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) -> URL {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent(relativePath)
        ]
        if let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return url
        }
        return candidates[0]
    }
}
