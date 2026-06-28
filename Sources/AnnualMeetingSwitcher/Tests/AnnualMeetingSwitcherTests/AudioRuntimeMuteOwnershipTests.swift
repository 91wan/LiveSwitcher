import XCTest
@testable import LiveSwitcher

@MainActor
final class AudioRuntimeMuteOwnershipTests: XCTestCase {
    func testFacadeAudioInputsChangedDoesNotMutateMediaState() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/current.mp4")
        state.media.isPlaying = false
        state.media.didPlayToEnd = true
        state.media.currentTime = 12
        let originalMedia = state.media

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(audioRuntimeOwnershipSnapshot(mediaPlaying: true)),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.media, originalMedia)
    }

    func testFacadeAudioInputsChangedDoesNotMutatePanicState() {
        var state = LiveRuntimeState()
        state.panic.isActive = false
        state.panic.generation = 4
        let originalPanic = state.panic

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(audioRuntimeOwnershipSnapshot(panic: true)),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.panic, originalPanic)
    }
}
