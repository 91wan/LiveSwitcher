import Foundation
import XCTest

func sourceText(_ relativePath: String, filePath: String = #filePath) throws -> String {
    let root = try repositoryRoot(filePath: filePath)
    if isLiveModeViewSourcePath(relativePath) {
        return try liveModeSourceTextAggregate(repositoryRoot: root)
    }
    if isProgramMonitorViewSourcePath(relativePath) {
        return try programMonitorSourceTextAggregate(repositoryRoot: root)
    }
    if isRunQueueViewSourcePath(relativePath) {
        return try runQueueSourceTextAggregate(repositoryRoot: root)
    }
    return try String(contentsOf: sourceURL(relativePath, repositoryRoot: root), encoding: .utf8)
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

let programMonitorSplitSourceRelativePaths = [
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorView.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorPreviewDeck.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorChrome.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorBlackoutOverlay.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorMediaLayer.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorWallpaperTray.swift"
]

let runQueueSplitSourceRelativePaths = [
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/SignalSourceRow.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/ProgramQueueDragHandle.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/ProgramQueueNumberBadge.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/ProgramQueueScheduleEditor.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/AgendaMarkerEditorPopover.swift",
    "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/ProgressSliderRow.swift"
]

func isLiveModeViewSourcePath(_ relativePath: String) -> Bool {
    relativePath.hasSuffix("Views/LiveModeView.swift")
}

func isProgramMonitorViewSourcePath(_ relativePath: String) -> Bool {
    relativePath.hasSuffix("Views/ProgramMonitorView.swift")
}

func isRunQueueViewSourcePath(_ relativePath: String) -> Bool {
    relativePath.hasSuffix("Views/RunQueueView.swift")
}

func liveModeSourceTextAggregate(repositoryRoot root: URL) throws -> String {
    try liveModeSplitSourceRelativePaths
        .map { try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8) }
        .joined(separator: "\n")
}

func programMonitorSourceTextAggregate(repositoryRoot root: URL) throws -> String {
    try programMonitorSplitSourceRelativePaths
        .map { try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8) }
        .joined(separator: "\n")
}

func runQueueSourceTextAggregate(repositoryRoot root: URL) throws -> String {
    try runQueueSplitSourceRelativePaths
        .map { try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8) }
        .joined(separator: "\n")
}

private func sourceURL(_ relativePath: String, repositoryRoot root: URL) -> URL {
    let directCandidate = root.appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: directCandidate.path) {
        return directCandidate
    }

    let sourceRootCandidate = root
        .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
        .appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: sourceRootCandidate.path) {
        return sourceRootCandidate
    }

    let legacySourcePrefix = "Sources/AnnualMeetingSwitcher/"
    if relativePath.hasPrefix(legacySourcePrefix) {
        let suffix = String(relativePath.dropFirst(legacySourcePrefix.count))
        let legacyCandidate = root
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            .appendingPathComponent(suffix)
        if FileManager.default.fileExists(atPath: legacyCandidate.path) {
            return legacyCandidate
        }
    }

    return directCandidate
}
