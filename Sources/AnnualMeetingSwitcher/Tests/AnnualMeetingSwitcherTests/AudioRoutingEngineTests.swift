import XCTest
@testable import LiveSwitcher

final class AudioRoutingEngineTests: XCTestCase {
    private func input(
        masterVolume: Double = 0.8,
        mediaVolume: Double = 0.5,
        bgmVolume: Double = 0.6,
        audioStrategy: AudioStrategy = .mixed,
        isCurrentProgramMediaSource: Bool = true,
        isMediaPlaying: Bool = true,
        isBGMAudioTakeoverActive: Bool = false,
        isSpeakerMode: Bool = false,
        isPanicMode: Bool = false,
        isMasterMuted: Bool = false,
        isMediaMuted: Bool = false,
        isBGMMuted: Bool = false,
        speakerModeDuckedRatio: Float = 0.07
    ) -> AudioRoutingInput {
        AudioRoutingInput(
            masterVolume: masterVolume,
            mediaVolume: mediaVolume,
            bgmVolume: bgmVolume,
            audioStrategy: audioStrategy,
            isCurrentProgramMediaSource: isCurrentProgramMediaSource,
            isMediaPlaying: isMediaPlaying,
            isBGMAudioTakeoverActive: isBGMAudioTakeoverActive,
            isSpeakerMode: isSpeakerMode,
            isPanicMode: isPanicMode,
            isMasterMuted: isMasterMuted,
            isMediaMuted: isMediaMuted,
            isBGMMuted: isBGMMuted,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    func testMixedOutputsMediaAndBGM() {
        let output = AudioRoutingEngine.output(for: input())

        XCTAssertEqual(output.media, 0.4, accuracy: 0.0001)
        XCTAssertEqual(output.bgm, 0.48, accuracy: 0.0001)
    }

    func testPanicMutesBothOutputs() {
        let output = AudioRoutingEngine.output(for: input(isPanicMode: true))

        XCTAssertEqual(output.media, 0, accuracy: 0.0001)
        XCTAssertEqual(output.bgm, 0, accuracy: 0.0001)
    }

    func testLiveMuteControlsApplyThroughRoutingEngine() {
        let masterMuted = AudioRoutingEngine.output(for: input(isMasterMuted: true))
        XCTAssertEqual(masterMuted.media, 0, accuracy: 0.0001)
        XCTAssertEqual(masterMuted.bgm, 0, accuracy: 0.0001)

        let mediaMuted = AudioRoutingEngine.output(for: input(isMediaMuted: true))
        XCTAssertEqual(mediaMuted.media, 0, accuracy: 0.0001)
        XCTAssertEqual(mediaMuted.bgm, 0.48, accuracy: 0.0001)

        let bgmMuted = AudioRoutingEngine.output(for: input(isBGMMuted: true))
        XCTAssertEqual(bgmMuted.media, 0.4, accuracy: 0.0001)
        XCTAssertEqual(bgmMuted.bgm, 0, accuracy: 0.0001)
    }

    func testBGMTakeoverMutesMediaAndKeepsBGM() {
        let output = AudioRoutingEngine.output(
            for: input(audioStrategy: .followSource, isBGMAudioTakeoverActive: true)
        )

        XCTAssertEqual(output.media, 0, accuracy: 0.0001)
        XCTAssertEqual(output.bgm, 0.48, accuracy: 0.0001)
    }

    func testFollowSourceWithMediaSourceKeepsBGMMutedUnlessTakeoverIsExplicit() {
        let output = AudioRoutingEngine.output(for: input(audioStrategy: .followSource))

        XCTAssertEqual(output.media, 0.4, accuracy: 0.0001)
        XCTAssertEqual(output.bgm, 0, accuracy: 0.0001)
    }

    func testBGMOnlyMutesMediaAndKeepsBGM() {
        let output = AudioRoutingEngine.output(for: input(audioStrategy: .bgmOnly))

        XCTAssertEqual(output.media, 0, accuracy: 0.0001)
        XCTAssertEqual(output.bgm, 0.48, accuracy: 0.0001)
    }

    func testSpeakerModeDucksWithoutRaisingLowerFader() {
        let loudOutput = AudioRoutingEngine.output(for: input(isSpeakerMode: true))
        XCTAssertEqual(loudOutput.media, 0.056, accuracy: 0.0001)
        XCTAssertEqual(loudOutput.bgm, 0.056, accuracy: 0.0001)

        let quietOutput = AudioRoutingEngine.output(
            for: input(masterVolume: 0.8, mediaVolume: 0.02, bgmVolume: 0.01, isSpeakerMode: true)
        )
        XCTAssertEqual(quietOutput.media, 0.016, accuracy: 0.0001)
        XCTAssertEqual(quietOutput.bgm, 0.008, accuracy: 0.0001)
    }

    func testFollowProgramDropsBGMOnlyWhileMediaIsPlaying() {
        let playingOutput = AudioRoutingEngine.output(for: input(audioStrategy: .followProgram))
        XCTAssertEqual(playingOutput.media, 0.4, accuracy: 0.0001)
        XCTAssertEqual(playingOutput.bgm, 0, accuracy: 0.0001)

        let idleOutput = AudioRoutingEngine.output(
            for: input(audioStrategy: .followProgram, isMediaPlaying: false)
        )
        XCTAssertEqual(idleOutput.media, 0, accuracy: 0.0001)
        XCTAssertEqual(idleOutput.bgm, 0.48, accuracy: 0.0001)
    }
}
