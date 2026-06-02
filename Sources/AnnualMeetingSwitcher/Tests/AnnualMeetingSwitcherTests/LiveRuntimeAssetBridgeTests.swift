import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeAssetBridgeTests: XCTestCase {
    func testRuntimeAssetActionsRequestImageLoadEffects() {
        let wallpaperURL = URL(fileURLWithPath: "/tmp/live-switcher-wallpaper.png")
        let logoURL = URL(fileURLWithPath: "/tmp/live-switcher-logo.png")

        let wallpaper = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetActiveWallpaperURL(wallpaperURL),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let logo = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetCornerLogoURL(logoURL),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(wallpaper.state.preferences.activeWallpaperURL, wallpaperURL)
        XCTAssertTrue(wallpaper.effects.contains(.loadBackgroundImage(wallpaperURL)))
        XCTAssertEqual(logo.state.preferences.cornerLogoURL, logoURL)
        XCTAssertTrue(logo.effects.contains(.loadCornerLogoImage(logoURL)))
    }

    func testEffectRunnerInvokesInjectedImageAssetPort() {
        let wallpaperURL = URL(fileURLWithPath: "/tmp/live-switcher-wallpaper.png")
        let logoURL = URL(fileURLWithPath: "/tmp/live-switcher-logo.png")
        let images = ImageAssetPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, imageAssets: images)

        runner.run(
            [
                .loadBackgroundImage(wallpaperURL),
                .loadCornerLogoImage(logoURL),
                .loadBackgroundImage(nil),
                .loadCornerLogoImage(nil)
            ],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in XCTFail("Image asset effects should not dispatch actions") }
        )

        XCTAssertEqual(images.loadedBackgroundImages, [wallpaperURL, nil])
        XCTAssertEqual(images.loadedCornerLogoImages, [logoURL, nil])
    }

    func testViewModelAssetURLSettersRouteLoadingThroughRuntimePort() {
        let wallpaperURL = URL(fileURLWithPath: "/tmp/live-switcher-wallpaper.png")
        let logoURL = URL(fileURLWithPath: "/tmp/live-switcher-logo.png")
        let images = ImageAssetPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, imageAssets: images)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: isolatedDefaults(),
            runtime: runtime
        )

        viewModel.activeWallpaperURL = wallpaperURL
        viewModel.cornerLogoURL = logoURL

        XCTAssertEqual(runtime.state.preferences.activeWallpaperURL, wallpaperURL)
        XCTAssertEqual(runtime.state.preferences.cornerLogoURL, logoURL)
        XCTAssertEqual(images.loadedBackgroundImages, [wallpaperURL])
        XCTAssertEqual(images.loadedCornerLogoImages, [logoURL])
    }

    func testAssetURLDidSetDoesNotCallImageLoadersDirectly() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertFalse(source.contains("loadBackgroundImage(from: activeWallpaperURL)"))
        XCTAssertFalse(source.contains("loadCornerLogoImage(from: cornerLogoURL)"))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.operatorSetActiveWallpaperURL(activeWallpaperURL))"))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.operatorSetCornerLogoURL(cornerLogoURL))"))
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "LiveRuntimeAssetBridgeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private final class ImageAssetPortSpy: ImageAssetPort {
    private(set) var loadedBackgroundImages: [URL?] = []
    private(set) var loadedCornerLogoImages: [URL?] = []

    func loadBackgroundImage(from url: URL?) {
        loadedBackgroundImages.append(url)
    }

    func loadCornerLogoImage(from url: URL?) {
        loadedCornerLogoImages.append(url)
    }
}
