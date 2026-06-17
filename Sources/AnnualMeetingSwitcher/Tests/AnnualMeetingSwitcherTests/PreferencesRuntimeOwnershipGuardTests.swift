import XCTest
@testable import LiveSwitcher

final class PreferencesRuntimeOwnershipGuardTests: XCTestCase {
    func testConsoleModeNoopsBeforePersistenceOwnership() {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetConsoleMode(.live), bridgeMode: .recordingOnly)

        XCTAssertEqual(mutation.state.mode, state.mode)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testThemeOverrideNoopsBeforePersistenceOwnership() {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetThemeOverride(.system), bridgeMode: .recordingOnly)

        XCTAssertEqual(mutation.state.preferences.themeOverride, state.preferences.themeOverride)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAutoPlayNextVideoNoopsBeforePersistenceOwnership() {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetAutoPlayNextVideoOnEnd(true), bridgeMode: .recordingOnly)

        XCTAssertEqual(mutation.state.preferences.autoPlayNextVideoOnEnd, state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAutoAdvanceNoopsBeforePersistenceOwnership() {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetAutoAdvanceAtScheduledTime(true), bridgeMode: .recordingOnly)

        XCTAssertEqual(mutation.state.preferences.autoAdvanceAtScheduledTime, state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testShowAgendaTimelineNoopsBeforePersistenceOwnership() {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetShowAgendaTimeline(false), bridgeMode: .recordingOnly)

        XCTAssertEqual(mutation.state.preferences.showAgendaTimeline, state.preferences.showAgendaTimeline)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testCornerLogoPositionNoopsBeforePersistenceOwnership() {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetCornerLogoPosition(.bottomRight), bridgeMode: .recordingOnly)

        XCTAssertEqual(mutation.state.preferences.cornerLogoPosition, state.preferences.cornerLogoPosition)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testWallpaperURLNoopsBeforePersistenceAndImageAssetsOwnership() {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetActiveWallpaperURL(wallpaperURL), bridgeMode: .recordingOnly)

        XCTAssertEqual(mutation.state.preferences.activeWallpaperURL, state.preferences.activeWallpaperURL)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testWallpaperURLStillRequiresPersistenceAndImageAssetsOwnership() throws {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetActiveWallpaperURL(wallpaperURL), bridgeMode: .recordingOnly)
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        XCTAssertEqual(mutation.state.preferences.activeWallpaperURL, state.preferences.activeWallpaperURL)
        XCTAssertTrue(mutation.effects.isEmpty)
        assertCase(".operatorSetActiveWallpaperURL(let url)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode),")
        assertCase(".operatorSetActiveWallpaperURL(let url)", in: source, contains: "isRuntimeOwned(.imageAssets, in: bridgeMode)")
    }

    func testCornerLogoURLNoopsBeforePersistenceAndImageAssetsOwnership() {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetCornerLogoURL(logoURL), bridgeMode: .recordingOnly)

        XCTAssertEqual(mutation.state.preferences.cornerLogoURL, state.preferences.cornerLogoURL)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testCornerLogoURLStillRequiresPersistenceAndImageAssetsOwnership() throws {
        let state = guardedState()
        let mutation = reduce(state, .operatorSetCornerLogoURL(logoURL), bridgeMode: .recordingOnly)
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        XCTAssertEqual(mutation.state.preferences.cornerLogoURL, state.preferences.cornerLogoURL)
        XCTAssertTrue(mutation.effects.isEmpty)
        assertCase(".operatorSetCornerLogoURL(let url)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode),")
        assertCase(".operatorSetCornerLogoURL(let url)", in: source, contains: "isRuntimeOwned(.imageAssets, in: bridgeMode)")
    }

    func testPreferenceActionsMutateWhenPersistenceOwned() {
        [
            reduce(.operatorSetConsoleMode(.live), bridgeMode: .audioOwned).state.mode == .live,
            reduce(.operatorSetThemeOverride(.system), bridgeMode: .audioOwned).state.preferences.themeOverride == .system,
            reduce(.operatorSetAutoPlayNextVideoOnEnd(true), bridgeMode: .audioOwned).state.preferences.autoPlayNextVideoOnEnd,
            reduce(.operatorSetAutoAdvanceAtScheduledTime(true), bridgeMode: .audioOwned).state.preferences.autoAdvanceAtScheduledTime,
            reduce(.operatorSetShowAgendaTimeline(true), bridgeMode: .audioOwned).state.preferences.showAgendaTimeline,
            reduce(.operatorSetCornerLogoPosition(.bottomLeft), bridgeMode: .audioOwned).state.preferences.cornerLogoPosition == .bottomLeft
        ].forEach { didMutate in
            XCTAssertTrue(didMutate)
        }
    }

    func testImagePreferenceActionsMutateWhenPersistenceAndImageAssetsOwned() {
        let wallpaper = reduce(.operatorSetActiveWallpaperURL(wallpaperURL), bridgeMode: .audioOwned)
        let logo = reduce(.operatorSetCornerLogoURL(logoURL), bridgeMode: .audioOwned)

        XCTAssertEqual(wallpaper.state.preferences.activeWallpaperURL, wallpaperURL)
        XCTAssertEqual(wallpaper.effects, [.loadBackgroundImage(wallpaperURL)])
        XCTAssertEqual(logo.state.preferences.cornerLogoURL, logoURL)
        XCTAssertEqual(logo.effects, [.loadCornerLogoImage(logoURL)])
    }

    func testAllPreferenceCasesHaveExplicitOwnershipGuard() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        assertCase(".operatorSetConsoleMode(let mode)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }")
        assertCase(".operatorSetThemeOverride(let theme)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }")
        assertCase(".operatorSetAutoPlayNextVideoOnEnd(let isEnabled)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }")
        assertCase(".operatorSetAutoAdvanceAtScheduledTime(let isEnabled)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }")
        assertCase(".operatorSetShowAgendaTimeline(let isEnabled)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }")
        assertCase(".operatorSetCornerLogoPosition(let position)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }")
        assertCase(".operatorSetActiveWallpaperURL(let url)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode),")
        assertCase(".operatorSetActiveWallpaperURL(let url)", in: source, contains: "isRuntimeOwned(.imageAssets, in: bridgeMode)")
        assertCase(".operatorSetCornerLogoURL(let url)", in: source, contains: "guard isRuntimeOwned(.persistence, in: bridgeMode),")
        assertCase(".operatorSetCornerLogoURL(let url)", in: source, contains: "isRuntimeOwned(.imageAssets, in: bridgeMode)")
    }

    private var wallpaperURL: URL {
        URL(fileURLWithPath: "/tmp/wallpaper.png")
    }

    private var logoURL: URL {
        URL(fileURLWithPath: "/tmp/logo.png")
    }

    private func guardedState() -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.preferences.themeOverride = .dark
        state.preferences.autoPlayNextVideoOnEnd = false
        state.preferences.autoAdvanceAtScheduledTime = false
        state.preferences.showAgendaTimeline = true
        state.preferences.cornerLogoPosition = .topRight
        state.preferences.activeWallpaperURL = URL(fileURLWithPath: "/tmp/existing-wallpaper.png")
        state.preferences.cornerLogoURL = URL(fileURLWithPath: "/tmp/existing-logo.png")
        return state
    }

    private func reduce(_ action: LiveRuntimeAction, bridgeMode: LiveRuntimeBridgeMode) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, bridgeMode: bridgeMode)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }

    private func assertCase(
        _ casePattern: String,
        in source: String,
        contains expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let range = source.range(of: "case \(casePattern):") else {
            return XCTFail("Missing case \(casePattern)", file: file, line: line)
        }
        let endIndex = source.index(range.lowerBound, offsetBy: 360, limitedBy: source.endIndex) ?? source.endIndex
        let body = String(source[range.lowerBound..<endIndex])

        XCTAssertTrue(body.contains(expected), "Missing guard in \(casePattern)", file: file, line: line)
    }
}
