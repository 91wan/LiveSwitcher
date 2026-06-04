import Foundation

enum AudioRoutingDefaults {
    static let speakerModeDuckedRatio: Float = 0.07
    static let liveAudioFadeDuration: Double = 2.0
}

struct AudioRoutingInput: Equatable {
    var masterVolume: Double
    var mediaVolume: Double
    var bgmVolume: Double
    var audioStrategy: AudioStrategy
    var isCurrentProgramMediaSource: Bool
    var isMediaPlaying: Bool
    var isBGMAudioTakeoverActive: Bool
    var isSpeakerMode: Bool
    var isPanicMode: Bool
    var isMasterMuted: Bool = false
    var isMediaMuted: Bool = false
    var isBGMMuted: Bool = false
    var speakerModeDuckedRatio: Float
}

struct AudioRoutingOutput: Equatable {
    var media: Float
    var bgm: Float
}

enum AudioRoutingEngine {
    static func output(for input: AudioRoutingInput) -> AudioRoutingOutput {
        guard !input.isPanicMode, !input.isMasterMuted else {
            return AudioRoutingOutput(media: 0, bgm: 0)
        }

        let media = shouldOutputMedia(input) && !input.isMediaMuted ? duckedVolumeIfNeeded(
            Float(input.masterVolume * input.mediaVolume),
            input: input
        ) : 0
        let bgm = shouldOutputBGM(input) && !input.isBGMMuted ? duckedVolumeIfNeeded(
            Float(input.masterVolume * input.bgmVolume),
            input: input
        ) : 0

        return AudioRoutingOutput(media: media, bgm: bgm)
    }

    private static func shouldOutputMedia(_ input: AudioRoutingInput) -> Bool {
        guard !input.isBGMAudioTakeoverActive else { return false }

        switch input.audioStrategy {
        case .bgmOnly:
            return false
        case .followProgram:
            return input.isCurrentProgramMediaSource && input.isMediaPlaying
        case .followSource, .mixed:
            return input.isCurrentProgramMediaSource
        }
    }

    private static func shouldOutputBGM(_ input: AudioRoutingInput) -> Bool {
        if input.isBGMAudioTakeoverActive {
            return true
        }

        switch input.audioStrategy {
        case .bgmOnly, .mixed:
            return true
        case .followSource:
            return false
        case .followProgram:
            return !(input.isCurrentProgramMediaSource && input.isMediaPlaying)
        }
    }

    private static func duckedVolumeIfNeeded(_ volume: Float, input: AudioRoutingInput) -> Float {
        guard input.isSpeakerMode else { return volume }
        return min(volume, Float(input.masterVolume) * input.speakerModeDuckedRatio)
    }
}
