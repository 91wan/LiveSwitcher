import Foundation
import XCTest

func sourceText(_ relativePath: String, filePath: String = #filePath) throws -> String {
    let root = try repositoryRoot(filePath: filePath)
    if isLiveModeViewSourcePath(relativePath) {
        return try liveModeSourceTextAggregate(repositoryRoot: root)
    }
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func repositoryRoot(filePath: String = #filePath) throws -> URL {
    var directory = URL(fileURLWithPath: filePath)
    while directory.pathComponents.count > 1 {
        directory.deleteLastPathComponent()
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
            return directory
        }
    }
    throw XCTSkip("Could not locate repository root from test source path.")
}

let liveModeSplitSourceRelativePaths = [
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveSourceRail.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveProgramStack.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveAudioStrip.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveQuickRail.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveQuickRail+BGM.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveQuickRail+Overlays.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveRuntimeStatusBar.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveWallpaperPickerThumb.swift"
]

func isLiveModeViewSourcePath(_ relativePath: String) -> Bool {
    relativePath.hasSuffix("Views/LiveModeView.swift")
}

func liveModeSourceTextAggregate(repositoryRoot root: URL) throws -> String {
    try liveModeSplitSourceRelativePaths
        .map { try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8) }
        .joined(separator: "\n")
}
