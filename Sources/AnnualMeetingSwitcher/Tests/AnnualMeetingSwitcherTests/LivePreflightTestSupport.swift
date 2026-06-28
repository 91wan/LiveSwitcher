import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
func makeLivePreflightTestViewModel() -> SwitcherViewModel {
    let viewModel = SwitcherViewModel(
        loadPersistedData: false,
        enableSystemVolumeObserver: false,
        userDefaults: .standard
    )
    viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
    viewModel.programActivationSideEffects.presentKeynote = { _ in }
    viewModel.programActivationSideEffects.openPPTX = { _ in }
    viewModel.programActivationSideEffects.presentActiveDeck = {}
    viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }
    viewModel.programActivationSideEffects.stopDeck = {}
    return viewModel
}

func livePreflightReadySnapshot() -> LivePreflightSnapshot {
    LivePreflightSnapshot(
        appVersion: "0.4.0",
        hasExternalDisplay: true,
        isBroadcasting: true,
        broadcastSafetyNotice: nil,
        programItemCount: 1,
        currentProgramTitle: "Opening Video",
        currentProgramSource: "Media",
        bgmItemCount: 1,
        isBGMPlaying: false,
        isBGMAudioTakeoverActive: false,
        isSpeakerMode: false,
        isPanicMode: false,
        isPageInterceptEnabled: false,
        activeOverlayCount: 0,
        wallpaperCount: 1,
        autoPlayNextVideoOnEnd: false,
        effectiveMediaVolume: 0.5,
        effectiveBGMVolume: 0.5
    )
}

func livePreflightCheck(
    _ id: String,
    in checks: [LivePreflightCheck],
    file: StaticString = #filePath,
    line: UInt = #line
) -> LivePreflightCheck {
    guard let check = checks.first(where: { $0.id == id }) else {
        XCTFail("Missing preflight check: \(id)", file: file, line: line)
        return LivePreflightCheck(
            id: id,
            group: .controls,
            status: .fail,
            title: "missing",
            message: "missing"
        )
    }
    return check
}
