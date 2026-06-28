import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
func persistentRuntimeLoadMakeViewModel(
    runtimeState: LiveRuntimeState = LiveRuntimeState(),
    bridgeMode: LiveRuntimeBridgeMode
) -> SwitcherViewModel {
    let runtime = LiveRuntimeStore(
        initialState: runtimeState,
        effectRunner: .recording(),
        environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
    )
    return SwitcherViewModel(
        loadPersistedData: false,
        enableSystemVolumeObserver: false,
        runtime: runtime
    )
}

func persistentRuntimeLoadProgramItem(_ title: String) -> ProgramItem {
    ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
}

func persistentRuntimeLoadSource() throws -> String {
    try XCTUnwrap(optionalRepositorySource(
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Persistence.swift"
    ))
}

@MainActor
func persistentRuntimeLoadMakePNG(name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("live-switcher-\(name)-\(UUID().uuidString)")
        .appendingPathExtension("png")
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: 2, height: 2).fill()
    image.unlockFocus()
    let data = try XCTUnwrap(image.tiffRepresentation)
    let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
    return url
}

@MainActor
func persistentRuntimeLoadWaitForCornerLogoReady(_ viewModel: SwitcherViewModel, activeURL: URL) async {
    for _ in 0..<100 {
        if viewModel.cornerLogoLoadPhase == .ready(activeURL: activeURL) {
            return
        }
        await Task.yield()
    }
    XCTFail("Corner logo did not become ready")
}
