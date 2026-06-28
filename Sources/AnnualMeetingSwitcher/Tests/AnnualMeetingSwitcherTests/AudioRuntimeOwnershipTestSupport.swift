import XCTest
@testable import LiveSwitcher

func audioRuntimeOwnershipSourceText(_ relativePath: String) throws -> String {
    var directory = URL(fileURLWithPath: #filePath)
    while directory.pathComponents.count > 1 {
        directory.deleteLastPathComponent()
        let candidate = directory
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            .appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return try String(contentsOf: candidate, encoding: .utf8)
        }
    }
    throw XCTSkip("Could not locate \(relativePath) from test source path.")
}

func audioRuntimeOwnershipSnapshot(
    mediaPlaying: Bool = false,
    bgmPlaying: Bool = false,
    panic: Bool = false
) -> AudioFacadeSnapshot {
    AudioFacadeSnapshot(
        masterVolume: 0.5,
        mediaVolume: 0.8,
        bgmVolume: 0.2,
        strategy: .mixed,
        isMasterMuted: false,
        isMediaMuted: false,
        isBGMMuted: false,
        isSpeakerMode: false,
        isBGMTakeoverActive: false,
        isPanicMode: panic,
        isCurrentProgramMediaSource: true,
        isMediaPlaying: mediaPlaying,
        isBGMPlaying: bgmPlaying
    )
}

extension String {
    func audioRuntimeOwnershipFunctionBody(named functionName: String) -> String? {
        guard let nameRange = range(of: "func \(functionName)") else { return nil }
        guard let openingBrace = self[nameRange.lowerBound...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            let character = self[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}

final class AudioRuntimeOwnershipPortSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []
    private(set) var states: [LiveRuntimeState] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
        states.append(state)
    }
}
