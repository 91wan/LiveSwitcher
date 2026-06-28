import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentStateRuntimeLoadOverlayTests: XCTestCase {
    func testPersistentLoadStillLoadsBackgroundImage() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)
        let url = URL(fileURLWithPath: "/tmp/persistent-background.png")

        viewModel.applyPersistentState(SwitcherPersistentState(activeWallpaperURL: url))

        XCTAssertNotNil(viewModel.backgroundImage)
    }

    func testPersistentLoadStillLoadsCornerLogoImage() async throws {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)
        let url = try persistentRuntimeLoadMakePNG(name: "persistent-logo")

        viewModel.applyPersistentState(SwitcherPersistentState(cornerLogoURL: url))
        await persistentRuntimeLoadWaitForCornerLogoReady(viewModel, activeURL: url)

        XCTAssertNotNil(viewModel.cornerLogoImage)
    }

    func testPersistentLoadStillClearsBackgroundImageForNilURL() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)
        viewModel.backgroundImage = NSImage(size: NSSize(width: 1, height: 1))

        viewModel.applyPersistentState(SwitcherPersistentState(activeWallpaperURL: nil))

        XCTAssertNil(viewModel.backgroundImage)
    }

    func testPersistentLoadStillClearsCornerLogoImageForNilURL() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)
        viewModel.cornerLogoImage = NSImage(size: NSSize(width: 1, height: 1))

        viewModel.applyPersistentState(SwitcherPersistentState(cornerLogoURL: nil))

        XCTAssertNil(viewModel.cornerLogoImage)
    }

    func testPersistentProjectionDoesNotDuplicateImageLoadThroughRuntimeEffects() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(
            activeWallpaperURL: URL(fileURLWithPath: "/tmp/background.png"),
            cornerLogoURL: URL(fileURLWithPath: "/tmp/logo.png")
        ))

        XCTAssertFalse(viewModel.runtime.recordedEffects.contains {
            switch $0 {
            case .loadBackgroundImage, .loadCornerLogoImage:
                return true
            default:
                return false
            }
        })
    }
}
