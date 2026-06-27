import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

final class SwitcherViewModelSmokeOutputWindowControllerSpy: OutputWindowControlling {
    var onExternalDisplayUnavailable: (() -> Void)?
    private(set) var mountCount = 0
    private(set) var showCount = 0
    private(set) var hideCount = 0
    private(set) var lastShowScreenWasNil = false

    func mountAnyView(rootView: AnyView) {
        mountCount += 1
    }

    func show(on screen: NSScreen?) {
        showCount += 1
        lastShowScreenWasNil = (screen == nil)
    }

    func hide() {
        hideCount += 1
    }
}

@MainActor
class SwitcherViewModelSmokeTestCase: XCTestCase {
    func makeViewModel(userDefaults: UserDefaults? = nil, loadPersistedData: Bool = false) -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(
            loadPersistedData: loadPersistedData,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults ?? .standard
        )
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.programActivationSideEffects.presentKeynote = { _ in }
        viewModel.programActivationSideEffects.openPPTX = { _ in }
        viewModel.programActivationSideEffects.presentActiveDeck = {}
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }
        viewModel.programActivationSideEffects.stopDeck = {}
        return viewModel
    }

    func makeIsolatedDefaults() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "LiveSwitcherTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (suiteName, defaults)
    }

    func makeTempFileURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: Data("stub".utf8))
        return url
    }

    func mirrorRuntimeMediaState(
        _ viewModel: SwitcherViewModel,
        item: ProgramItem,
        isPlaying: Bool
    ) {
        mirrorRuntimeCurrentProgramState(viewModel, item: item, isPlaying: isPlaying)
    }

    func mirrorRuntimeCurrentProgramState(
        _ viewModel: SwitcherViewModel,
        item: ProgramItem,
        isPlaying: Bool = false
    ) {
        var state = viewModel.runtime.state
        state.program.items = [item]
        state.program.currentID = item.id
        state.program.currentDetachedItem = nil
        state.program.currentSwitchedAt = Date()
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = isPlaying
        viewModel.runtime.replaceStateForFacadeSync(state)
    }

    func makeEmptyTempFileURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }

    func makeTempDirectoryURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    func makeWallpaperURL() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()

        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: url)
        return url
    }
}
