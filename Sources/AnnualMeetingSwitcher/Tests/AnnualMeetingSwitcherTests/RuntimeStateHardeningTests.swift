import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeStateHardeningTests: XCTestCase {
    func testAudioStrategyUsesStablePersistenceSlugsAndLegacyChineseMigration() throws {
        XCTAssertEqual(AudioStrategy.mixed.rawValue, "mixed")
        XCTAssertEqual(AudioStrategy.followProgram.rawValue, "followProgram")
        XCTAssertEqual(AudioStrategy.followSource.rawValue, "followSource")
        XCTAssertEqual(AudioStrategy.bgmOnly.rawValue, "bgmOnly")
        XCTAssertEqual(AudioStrategy(persistedValue: "混合"), .mixed)
        XCTAssertEqual(AudioStrategy(persistedValue: "音频跟随"), .followProgram)
        XCTAssertEqual(AudioStrategy(persistedValue: "跟随源"), .followSource)
        XCTAssertEqual(AudioStrategy(persistedValue: "仅 BGM"), .bgmOnly)
        XCTAssertEqual(AudioStrategy.mixed.displayTitle, "混合")

        let (_, defaults) = makeIsolatedDefaults()
        defaults.set("跟随源", forKey: "audioStrategy")

        let viewModel = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(viewModel.audioStrategy, .followSource)
        XCTAssertEqual(defaults.string(forKey: "audioStrategy"), "followSource")
    }

    func testLoadDataRecordsMissingRestoredFilesWithoutLeakingPaths() {
        let (_, defaults) = makeIsolatedDefaults()
        defaults.set(["/tmp/missing-program.mp4"], forKey: "pushList_paths")
        defaults.set(["Private Program"], forKey: "pushList_titles")
        defaults.set(["VIDEO"], forKey: "pushList_subtitles")
        defaults.set(["/tmp/missing-bgm.mp3"], forKey: "bgmList_paths")
        defaults.set(["Private BGM"], forKey: "bgmList_titles")
        defaults.set([BGMCategory.warmUp.rawValue], forKey: "bgmList_categories")
        defaults.set(["/tmp/missing-wallpaper.png"], forKey: "backgroundWallpapers_paths")

        let viewModel = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertTrue(viewModel.bgmItems.isEmpty)
        XCTAssertTrue(viewModel.backgroundWallpapers.isEmpty)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .programItemFileMissing })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .bgmFileMissing })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .wallpaperFileMissing })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("/tmp/missing") })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("Private") })
    }

    func testWallpaperPolicyAcceptsImageContentTypeWithoutExtensionAndRejectsUnknownFiles() {
        let extensionlessImage = URL(fileURLWithPath: "/tmp/wallpaper-file")
        let textFile = URL(fileURLWithPath: "/tmp/wallpaper.txt")

        XCTAssertTrue(
            WallpaperImagePolicy.isSupported(
                url: extensionlessImage,
                fileExists: { _ in true },
                contentType: { _ in .png }
            )
        )
        XCTAssertFalse(
            WallpaperImagePolicy.isSupported(
                url: textFile,
                fileExists: { _ in true },
                contentType: { _ in .plainText }
            )
        )
        XCTAssertFalse(
            WallpaperImagePolicy.isSupported(
                url: extensionlessImage,
                fileExists: { _ in false },
                contentType: { _ in .png }
            )
        )
    }

    private func makeIsolatedDefaults() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "LiveSwitcherTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (suiteName, defaults)
    }
}
